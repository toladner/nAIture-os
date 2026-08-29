/*
 * One entry in a start-sheet column. The design draws these as flat slabs —
 * 9px/12px of padding, a 10px radius, a hairline — that fill in on hover. A
 * row the keyboard has walked onto also carries the accent bar the dock and
 * the time pill use, so "this one" is said the same way everywhere.
 */
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: row

    property alias label: text.text

    // A var, not a string: a row can be handed KRunner's own decoration, which
    // is an icon name most of the time and a QIcon the rest of it, and
    // Kirigami.Icon takes either.
    property var iconSource: ""
    property string detail: ""
    property bool selected: false
    property color accent: Kirigami.Theme.highlightColor

    // A column that reorders its rows takes the pointer over from here, so the
    // row draws hover rather than sensing it. The power menu, which does not,
    // keeps its own MouseArea.
    property bool interactive: true
    property bool externalHover: false

    // Whether this row can be kept at the top of its column, and whether it
    // currently is. The pin shows through once a row is pinned and only comes
    // out from under the pointer before that, so a column of unpinned rows is
    // as quiet as it was.
    property bool pinnable: false
    property bool pinned: false

    // The pin's own MouseArea counts as being on the row: it sits over the
    // row's, so without this the pointer moving onto the pin would take the
    // hover away, hide the pin it is standing on, and get it back — a flicker
    // at the speed of the layout.
    readonly property bool hovered:
        mouse.containsMouse || externalHover || pinMouse.containsMouse

    signal activated()
    signal entered()
    signal pinToggled()

    height: Tokens.rowHeight
    radius: Tokens.rowRadius
    color: hovered || selected ? Tokens.rowHover : Tokens.rowFill
    border.width: 1
    border.color: selected ? row.accent : Tokens.rowBorder

    Behavior on color {
        ColorAnimation { duration: 90 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 90 }
    }

    Rectangle {
        // The marker, stood on its end: a column runs down the sheet, so the
        // bar that would sit above a dock icon sits beside a row instead.
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.markerThickness
        height: parent.height * 0.55
        radius: width / 2
        color: row.accent
        opacity: row.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    Kirigami.Icon {
        id: icon

        visible: row.iconSource !== "" && row.iconSource !== undefined
        anchors.left: parent.left
        anchors.leftMargin: Tokens.rowPadX
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.rowIcon
        height: Tokens.rowIcon
        source: row.iconSource

        // Never Kirigami's hover wash — the slab behind it says enough. The
        // dock learned this the hard way; see main.qml.
        active: false
    }

    Text {
        id: text

        anchors.left: icon.visible ? icon.right : parent.left
        anchors.leftMargin: icon.visible ? 10 : Tokens.rowPadX
        anchors.right: detailText.visible ? detailText.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        color: Tokens.text
        font.pointSize: Tokens.pt(12.5)
        elide: Text.ElideRight
    }

    Text {
        id: detailText

        visible: row.detail !== ""
        // The pin's room is kept whether or not it is showing, so a row does
        // not reflow under the pointer.
        anchors.right: row.pinnable ? pin.left : parent.right
        anchors.rightMargin: row.pinnable ? 6 : Tokens.rowPadX
        anchors.verticalCenter: parent.verticalCenter

        width: Math.min(implicitWidth, row.width * 0.42)
        text: row.detail
        color: Tokens.detail
        font.pointSize: Tokens.pt(11)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
    }

    // The pin, at the row's trailing edge and above everything else so a
    // click on it is never a click on the row.
    Item {
        id: pin

        visible: row.pinnable && (row.pinned || row.hovered)
        z: 2

        anchors.right: parent.right
        anchors.rightMargin: Tokens.rowPadX - 4
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.rowHeight - 10
        height: width

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Tokens.rowIcon - 3
            height: width

            source: "pin-symbolic"
            color: row.pinned ? row.accent : Tokens.text
            isMask: true
            active: false

            opacity: row.pinned ? 1 : (pinMouse.containsMouse ? 0.9 : 0.4)
            rotation: row.pinned ? 0 : -35

            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }

            Behavior on rotation {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: pinMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.pinToggled()
        }
    }

    MouseArea {
        id: mouse

        enabled: row.interactive
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
        onEntered: row.entered()
    }
}
