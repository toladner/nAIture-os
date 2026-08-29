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
    preferredRepresentation: compactRepresentation
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
        isSilent: !root.expanded
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

    compactRepresentation: Item {
        id: pill

        // The panel background contributes the design's 7px; the pill wants
        // 20px each side of the time.
        readonly property int sidePadding: 13

        Layout.minimumWidth: timeLabel.implicitWidth + sidePadding * 2
        Layout.preferredWidth: Layout.minimumWidth

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

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.expanded = !root.expanded
        }
    }

    // --- the sheet ------------------------------------------------------

    // The design's sheet is a 20px-rounded, 85%-opaque panel. Plasma 6.7 paints
    // the popup window itself — the theme's dialogs/background.svg is not used
    // for applet popups, and backgroundHints: NoBackground does not stop it —
    // so a rounded rectangle drawn in here only sits fake corners inside a
    // square box. What is left to us is the design's width and padding; the
    // shape, the shadow and the colour come from the popup and the scheme.
    fullRepresentation: Item {
        id: sheet

        Layout.minimumWidth: Tokens.sheetWidth
        Layout.maximumWidth: Tokens.sheetWidth
        Layout.minimumHeight: content.implicitHeight + Tokens.sheetPadY * 2
        Layout.maximumHeight: Layout.minimumHeight

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: Tokens.sheetPadX
            anchors.rightMargin: Tokens.sheetPadX
            anchors.topMargin: Tokens.sheetPadY
            anchors.bottomMargin: Tokens.sheetPadY
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

                PC3.Label {
                    text: root.timeText
                    font.pointSize: Tokens.pt(18)
                    font.features: ({ "tnum": 1 })
                    font.weight: Font.Medium
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
                opacity: settingsHover.hovered ? 1 : 0.45

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                HoverHandler {
                    id: settingsHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.expanded = false;
                        KCMUtils.KCMLauncher.openSystemSettings();
                    }
                }

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: i18n("All settings")
                }
            }
        }
    }
}
