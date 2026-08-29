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
 *   Do not disturb  org.kde.notificationmanager — Settings.notificationsInhibitedUntil
 *   Aeroplane    org.kde.plasma.networkmanagement — Handler.enableAirplaneMode
 *   Night light  org.kde.plasma.private.brightnesscontrolplugin — NightLightInhibitor
 *   Brightness   ...brightnesscontrolplugin — ScreenBrightnessControl
 *
 * Two of the design's six tiles have no counterpart on a real desktop: "Local
 * models · 3 warm" and "Field light · Follows sun". Rather than ship two tiles
 * that do nothing, this takes the nearest real controls — aeroplane mode and
 * night light — and keeps the design's glyphs and layout.
 */
import QtQml
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus

import org.kde.plasma.private.volume as Volume
import org.kde.plasma.private.brightnesscontrolplugin as BrightnessControl
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as Notifications

PlasmoidItem {
    id: root

    // Every colour in the sheet comes from the colour scheme, so changing the
    // accent (scripts/accent.sh, or System Settings) moves the whole sheet with
    // it and nothing here has to be edited.
    readonly property color accent: Kirigami.Theme.highlightColor

    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    // The sheet is drawn below, so Plasma must not draw one behind it: with a
    // background of its own the popup window would show square corners around
    // the design's rounded ones.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
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

    Notifications.Settings {
        id: notificationSettings
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
    readonly property bool dndOn: Notifications.Server.inhibited
    readonly property bool nightLightOn: !BrightnessControl.NightLightInhibitor.inhibited

    function dndDetail() {
        if (!dndOn) {
            return i18n("Notifications on");
        }
        const until = notificationSettings.notificationsInhibitedUntil;
        const ms = until ? until.getTime() : NaN;
        // A year out is the "until I turn it off" case the applet writes.
        if (!isNaN(ms) && ms > Date.now() && ms - Date.now() < 100 * 24 * 60 * 60 * 1000) {
            return i18nc("do not disturb until a time", "Until %1", Qt.formatTime(until, "HH:mm"));
        }
        return i18n("Until turned off");
    }

    function toggleDnd() {
        if (dndOn) {
            notificationSettings.notificationsInhibitedUntil = new Date(0);
            notificationSettings.save();
            Notifications.Server.inhibited = false;
        } else {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            notificationSettings.notificationsInhibitedUntil = until;
            notificationSettings.save();
        }
    }

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
            font.family: Tokens.monoFamily
            // The terminal's size, so the two read as one typeface at one size.
            // It still fits: the island's 42px leaves 28px of content height.
            font.pointSize: Tokens.terminalPointSize
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

    fullRepresentation: Rectangle {
        id: sheet

        // design/naiture-canvas.dc.html:
        //   width: 400; padding: 20px 22px; border-radius: 20px;
        //   background: rgba(13,24,17,0.85);
        //   border: 1px solid rgba(255,255,255,0.16);
        Layout.minimumWidth: Tokens.sheetWidth
        Layout.maximumWidth: Tokens.sheetWidth
        Layout.minimumHeight: content.implicitHeight + Tokens.sheetPadY * 2
        Layout.maximumHeight: Layout.minimumHeight

        radius: Tokens.sheetRadius
        color: Tokens.sheet
        border.width: 1
        border.color: Tokens.sheetBorder

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
                    font.family: Tokens.monoFamily
                    font.pointSize: Tokens.pt(18)
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
                    glyph: "◐"
                    name: i18n("Do not disturb")
                    on: root.dndOn
                    detail: root.dndDetail()
                    onToggled: root.toggleDnd()
                }

                QuickTile {
                    Layout.fillWidth: true
                    accent: root.accent
                    glyph: "⬡"
                    name: i18n("Aeroplane mode")
                    on: PlasmaNM.Configuration.airplaneModeEnabled
                    detail: on ? i18n("Radios off") : i18n("Radios on")
                    onToggled: networkHandler.enableAirplaneMode(!PlasmaNM.Configuration.airplaneModeEnabled)
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
        }
    }
}
