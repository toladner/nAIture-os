/*
 * naiture — the time pill and the quick-settings sheet behind it.
 *
 * Why this exists rather than a system tray plus a clock: Plasma's tray always
 * shows an expander chevron next to the time whenever anything is hidden
 * (applets/systemtray/qml/main.qml — `visible: root.hiddenLayout.itemCount > 0`,
 * with no setting to turn it off), and its popup is Plasma's own list rather
 * than the design's sheet. The design's island is the time alone, and clicking
 * the time is what opens the settings.
 *
 * Every control here drives the real thing, through the same APIs Plasma's own
 * applets use:
 *
 *   Wi-Fi        org.kde.plasma.networkmanagement — Handler.enableWireless
 *   Bluetooth    org.kde.bluezqt — Manager.usableAdapter.powered
 *   Sound        org.kde.plasma.private.volume — PreferredDevice.sink
 *   Night light  org.kde.plasma.private.brightnesscontrolplugin — NightLightInhibitor
 *   Brightness   ...brightnesscontrolplugin — ScreenBrightnessControl
 *
 * The design lays out six tiles. Two of them — "Local models · 3 warm" and
 * "Do not disturb" — are gone by request, and "Field light · Follows sun"
 * became night light, which is the real control it describes.
 */
import QtQml
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kcmutils as KCMUtils

import org.kde.plasma.private.volume as Volume
import org.kde.plasma.private.brightnesscontrolplugin as BrightnessControl
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt

PlasmoidItem {
    id: root

    // Every colour in the sheet comes from the colour scheme, so changing the
    // accent (scripts/accent.sh, or System Settings) moves the whole sheet with
    // it and nothing here has to be edited.
    readonly property color accent: Kirigami.Theme.highlightColor

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    // The panel background contributes the design's 7px; the pill wants 20px
    // each side of the time.
    readonly property int sidePadding: 13

    // Measured on the applet, because the label that would report it lives
    // inside the representation and is created later.
    TextMetrics {
        id: timeMetrics
        font.pointSize: Tokens.terminalPointSize
        font.weight: Font.Medium
        text: root.timeText
    }

    Layout.minimumWidth: horizontal ? Math.ceil(timeMetrics.width) + sidePadding * 2 : 0
    Layout.preferredWidth: Layout.minimumWidth
    Layout.fillHeight: horizontal
    Layout.fillWidth: !horizontal

    preferredRepresentation: fullRepresentation
    toolTipMainText: Qt.formatDate(clock.now, Locale.LongFormat)
    toolTipSubText: i18n("Quick settings")

    // --- the clock ------------------------------------------------------

    QtObject {
        id: clock
        property date now: new Date()
    }

    Timer {
        id: tick
        // Fire just after the next minute rolls over rather than every second.
        interval: 60000 - (clock.now.getSeconds() * 1000 + clock.now.getMilliseconds()) + 50
        running: true
        repeat: false
        onTriggered: {
            clock.now = new Date();
            restart();
        }
    }

    readonly property string timeText: Qt.formatTime(clock.now, "HH:mm")

    // --- backends -------------------------------------------------------

    PlasmaNM.Handler {
        id: networkHandler
    }

    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }

    PlasmaNM.AvailableDevices {
        id: availableDevices
    }

    PlasmaNM.WirelessStatus {
        id: wirelessStatus
    }

    // PreferredDevice.sink only tracks a sink while a SinkModel is alive.
    Volume.SinkModel {
        id: sinkModel
    }

    BrightnessControl.ScreenBrightnessControl {
        id: screenBrightness
        // Poll only while the sheet is open.
        isSilent: !sheetDialog.visible
    }

    // The display list is a bare QAbstractListModel whose roleNames() is not
    // exposed to QML, so the values are reached the way Plasma's own brightness
    // applet reaches them — through a delegate with `required property`
    // bindings, which resolves the roles for us.
    property real brightnessRatio: 0

    Instantiator {
        id: displays

        model: screenBrightness.displays

        delegate: QtObject {
            required property string displayName
            required property int brightness
            required property int maxBrightness

            readonly property real ratio: maxBrightness > 0 ? brightness / maxBrightness : 0

            onRatioChanged: root.syncBrightness()
            Component.onCompleted: root.syncBrightness()
        }

        onCountChanged: root.syncBrightness()
    }

    // One slider for however many screens there are: it shows their average and
    // moves them together, which is what a single-slider design implies.
    function syncBrightness() {
        let total = 0;
        let seen = 0;
        for (let i = 0; i < displays.count; i++) {
            const display = displays.objectAt(i);
            if (display) {
                total += display.ratio;
                seen += 1;
            }
        }
        root.brightnessRatio = seen > 0 ? total / seen : 0;
    }

    function setBrightness(ratio) {
        for (let i = 0; i < displays.count; i++) {
            const display = displays.objectAt(i);
            if (display && display.maxBrightness > 0) {
                screenBrightness.setBrightness(display.displayName,
                                               Math.round(ratio * display.maxBrightness));
            }
        }
    }

    // --- derived state --------------------------------------------------

    readonly property var sink: Volume.PreferredDevice.sink
    readonly property real volumeRatio: sink ? sink.volume / Volume.PulseAudio.NormalVolume : 0
    readonly property bool soundOn: !!sink && !sink.muted

    readonly property var btAdapter: BluezQt.Manager.usableAdapter
    readonly property bool bluetoothOn: !!btAdapter && btAdapter.powered
    readonly property int bluetoothConnected: BluezQt.Manager.connectedDevices ? BluezQt.Manager.connectedDevices.length : 0

    readonly property bool wifiOn: enabledConnections.wirelessEnabled
    readonly property bool nightLightOn: !BrightnessControl.NightLightInhibitor.inhibited



    // --- the pill -------------------------------------------------------

    fullRepresentation: Item {
        id: pill

        PC3.Label {
            id: timeLabel
            anchors.centerIn: parent
            text: root.timeText
            // The terminal's size, so the two read as one typeface at one size.
            // It still fits: the island's 42px leaves 28px of content height.
            font.pointSize: Tokens.terminalPointSize
            // Proportional digits would change the pill's width as the time
            // ticks, and the island is sized to its content.
            font.features: ({ "tnum": 1 })
            font.weight: Font.Medium
            color: Tokens.text
        }

        // Plasma's own open-applet marker rides on Plasmoid.expanded, which
        // this applet does not use; this is the same bar, drawn here.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: root.accent
            opacity: sheetDialog.visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sheetDialog.visible = !sheetDialog.visible
        }
    }

    // --- the sheet ------------------------------------------------------

    // The design's sheet is a 20px-rounded, 85%-opaque panel, and Plasma's own
    // applet popup cannot be one: on 6.7 that window paints an opaque
    // background of its own, which neither the theme's dialogs/background.svg
    // nor `backgroundHints: NoBackground` stops. A rounded rectangle inside it
    // only sits fake corners in a square box — swapping the theme's dialog SVG
    // for a solid colour proves the popup never reads it. A PlasmaCore.Dialog
    // does honour NoBackground, so the sheet lives in one of those and
    // Plasmoid.expanded is not used at all.
    //
    // The one thing that costs is Plasma's "this applet is open" accent bar,
    // which keys off Plasmoid.expanded. The pill draws its own.
    PlasmaCore.Dialog {
        id: sheetDialog

        // compactRepresentationItem is null for an applet that never sets
        // Plasmoid.expanded, so the dialog hangs off the applet itself.
        visualParent: root
        location: Plasmoid.location
        type: PlasmaCore.Dialog.AppletPopup
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true

        // The dialog sizes itself from mainItem's *implicit* size and then
        // assigns the real one back, so the item must not try to set its own
        // width and height — and the content inside must not be anchored to it
        // either, or the implicit height is a loop and the dialog falls back to
        // its default 400x300.
        mainItem: Rectangle {
            id: sheet

            implicitWidth: Tokens.sheetWidth
            implicitHeight: content.implicitHeight + Tokens.sheetPadY * 2

            radius: Tokens.sheetRadius
            color: Tokens.sheet
            border.width: 1
            border.color: Tokens.sheetBorder

            ColumnLayout {
                id: content

                x: Tokens.sheetPadX
                y: Tokens.sheetPadY
                width: sheet.width - Tokens.sheetPadX * 2
                spacing: Tokens.sectionGap

                // Header: the date and what the machine is connected to, with the
                // time repeated large on the right.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        PC3.Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Qt.formatDate(clock.now, "dddd d MMMM")
                            font.pointSize: Tokens.pt(14.5)
                            font.weight: Font.DemiBold
                            color: Tokens.text
                        }

                        PC3.Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: {
                                const parts = [];
                                if (root.wifiOn && wirelessStatus.wifiSSID) {
                                    parts.push(wirelessStatus.wifiSSID);
                                }
                                if (root.bluetoothConnected > 0) {
                                    parts.push(i18np("%1 device", "%1 devices",
                                                     root.bluetoothConnected));
                                }
                                return parts.length ? parts.join(" · ")
                                                    : i18n("Not connected");
                            }
                            font.pointSize: Tokens.pt(11.5)
                            color: Tokens.textDim
                        }
                    }

                    // The design set this in mono at 18px against a 14.5px
                    // date; in one typeface that reads as a mismatch rather
                    // than a contrast, so the two now share a size and weight.
                    PC3.Label {
                        text: root.timeText
                        font.pointSize: Tokens.pt(14.5)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                        color: Tokens.text
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Tokens.tileGap
                    rowSpacing: Tokens.tileGap

                    QuickTile {
                        Layout.fillWidth: true
                        accent: root.accent
                        glyph: "≋"
                        name: i18n("Wi-Fi")
                        available: availableDevices.wirelessDeviceAvailable
                        on: root.wifiOn
                        detail: !available ? i18n("No adapter")
                              : !on ? i18n("Off")
                              : (wirelessStatus.wifiSSID || i18n("Not connected"))
                        onToggled: networkHandler.enableWireless(!root.wifiOn)
                    }

                    QuickTile {
                        Layout.fillWidth: true
                        accent: root.accent
                        glyph: "✳"
                        name: i18n("Bluetooth")
                        available: !!root.btAdapter
                        on: root.bluetoothOn
                        detail: !available ? i18n("No adapter")
                              : !on ? i18n("Off")
                              : root.bluetoothConnected > 0
                                ? i18np("%1 device", "%1 devices", root.bluetoothConnected)
                                : i18n("No devices")
                        onToggled: root.btAdapter.powered = !root.bluetoothOn
                    }

                    QuickTile {
                        Layout.fillWidth: true
                        accent: root.accent
                        glyph: "◑"
                        iconName: !root.soundOn ? "audio-volume-muted-symbolic"
                                : root.volumeRatio > 0.65 ? "audio-volume-high-symbolic"
                                : root.volumeRatio > 0.25 ? "audio-volume-medium-symbolic"
                                : "audio-volume-low-symbolic"
                        name: i18n("Sound")
                        available: !!root.sink
                        on: root.soundOn
                        detail: !available ? i18n("No output")
                              : !on ? i18n("Muted")
                              : Math.round(root.volumeRatio * 100) + "%"
                        onToggled: root.sink.muted = !root.sink.muted
                    }



                    QuickTile {
                        Layout.fillWidth: true
                        accent: root.accent
                        glyph: "☀"
                        name: i18n("Night light")
                        on: root.nightLightOn
                        detail: root.nightLightOn ? i18n("Follows sun") : i18n("Paused")
                        onToggled: BrightnessControl.NightLightInhibitor.toggleInhibition()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.sliderGap

                    QuickSlider {
                        Layout.fillWidth: true
                        name: i18n("Volume")
                        tint: root.accent
                        // The same icon Plasma's own volume applet picks.
                        iconName: !root.soundOn ? "audio-volume-muted-symbolic"
                                : root.volumeRatio > 0.65 ? "audio-volume-high-symbolic"
                                : root.volumeRatio > 0.25 ? "audio-volume-medium-symbolic"
                                : "audio-volume-low-symbolic"
                        iconIsButton: true
                        onIconActivated: if (root.sink) {
                            root.sink.muted = !root.sink.muted;
                        }
                        available: !!root.sink
                        value: root.volumeRatio
                        onMoved: ratio => {
                            root.sink.muted = false;
                            root.sink.volume = Math.round(ratio * Volume.PulseAudio.NormalVolume);
                        }
                    }

                    QuickSlider {
                        Layout.fillWidth: true
                        name: i18n("Brightness")
                        tint: root.accent
                        iconName: root.brightnessRatio > 0.5 ? "brightness-high-symbolic"
                                                             : "brightness-low-symbolic"
                        available: screenBrightness.isBrightnessAvailable
                        value: root.brightnessRatio
                        onMoved: ratio => root.setBrightness(ratio)
                    }
                }

                // The sheet covers the handful of things worth a click; everything
                // else lives one step further in.
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small

                    source: "applications-system-symbolic"
                    opacity: settingsHover.containsMouse ? 1 : 0.45

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    MouseArea {
                        id: settingsHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        // KCMLauncher.openSystemSettings takes a module name and
                        // has no no-argument overload; calling it bare is a
                        // TypeError that a signal handler swallows in silence.
                        onClicked: {
                            sheetDialog.visible = false;
                            KCMUtils.KCMLauncher.openSystemSettings("kcm_landingpage");
                        }

                        PlasmaCore.ToolTipArea {
                            anchors.fill: parent
                            mainText: i18n("All settings")
                        }
                    }
                }
            }
        }
    }
}
