/*
 * naiture — show desktop edge.
 *
 * Windows puts "show desktop" in the last few pixels of the taskbar, at the
 * very corner of the screen, with no icon: the pointer can be thrown at the
 * corner without aiming. This is that, as the last applet in the right-hand
 * island, which is flush with the screen's edge.
 *
 * It is a separate applet rather than part of the time pill because Plasma
 * draws its "this applet's popup is open" accent bar across the whole applet.
 * Folded into the clock, that bar would span the strip too; kept apart, it sits
 * over the time alone.
 *
 * Two things a panel applet has to get right, and both are silent when wrong:
 *
 *   - The size hints belong on the PlasmoidItem itself, not on the
 *     representation. Put them on the representation and the panel reserves its
 *     own default width — about 40px here — and draws nothing in it.
 *   - An applet with no popup shows its `fullRepresentation` inline. Asking for
 *     `compactRepresentation` gives the collapsed form of a popup that does not
 *     exist. Plasma's own panel spacer is the model for both.
 *
 * KWin keeps the state on /KWin as `showingDesktop` and toggles it with
 * showDesktop(bool) — the same call Plasma's own Show Desktop widget makes.
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    // Just wide enough to be hit at the screen corner without being a button.
    readonly property int stripWidth: 8

    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    Layout.minimumWidth: horizontal ? stripWidth : 1
    Layout.preferredWidth: horizontal ? stripWidth : 0
    Layout.maximumWidth: horizontal ? stripWidth : Infinity
    Layout.minimumHeight: horizontal ? 1 : stripWidth
    Layout.preferredHeight: horizontal ? 0 : stripWidth
    Layout.maximumHeight: horizontal ? Infinity : stripWidth
    Layout.fillWidth: !horizontal
    Layout.fillHeight: horizontal

    preferredRepresentation: fullRepresentation

    toolTipMainText: i18n("Show desktop")
    toolTipSubText: i18n("Click to peek at the desktop, and again to come back")

    DBus.Properties {
        id: kwin
        busType: DBus.BusType.Session
        service: "org.kde.KWin"
        path: "/KWin"
        iface: "org.kde.KWin"
    }

    readonly property bool showing: kwin.properties.showingDesktop === true

    function toggle() {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/KWin",
            iface: "org.kde.KWin",
            member: "showDesktop",
            arguments: [!root.showing],
            signature: "(b)"
        });
    }

    fullRepresentation: Item {
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.toggle()
        }

        // The only mark it makes: a hairline that comes up under the pointer,
        // and stays up while the desktop is showing.
        Rectangle {
            anchors.centerIn: parent
            width: root.horizontal ? 1 : Math.round(parent.width * 0.55)
            height: root.horizontal ? Math.round(parent.height * 0.55) : 1
            radius: 0.5
            color: root.showing ? Kirigami.Theme.highlightColor : "#f2f7f2"
            opacity: hover.hovered || root.showing ? 0.6 : 0.18

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }
}
