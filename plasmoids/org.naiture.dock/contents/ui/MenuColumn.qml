/*
 * A titled column of entries, scrolling once it is taller than the sheet
 * allows. The design's column heading is uppercase and letterspaced; it was
 * monospaced there, which this desktop no longer is anywhere.
 */
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: column

    property string title: ""
    property var source: null
    property int rows: Tokens.minRows
    property bool showDetail: false
    property color accent: Kirigami.Theme.highlightColor

    // Which row the keyboard is on, or -1 for none. Set from outside: in the
    // search state the arrow keys walk this list while the field keeps focus.
    property int selected: -1

    property string emptyText: ""

    // A column of things that can be kept: its rows carry a pin, and a pinned
    // row can be dragged to sit above or below the other pinned ones. Only
    // those move — the rest of the column is in the order it was used, which
    // is not an order anyone can improve by hand.
    property bool pinnable: false

    // …and a column whose order is the user's to set. The search results are
    // not: they are in the order the query answered them.
    property bool reorderable: false

    signal triggered(int index)
    signal hovered(int index)
    signal pinToggled(int index)

    // While a row is being dragged, and once it is let go.
    signal moved(int from, int to)
    signal dropped()

    implicitHeight: Tokens.headingHeight + Tokens.headingGap + body.height

    onSelectedChanged: if (selected >= 0) {
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    Text {
        id: heading

        anchors.top: parent.top
        anchors.left: parent.left
        height: Tokens.headingHeight

        text: column.title.toUpperCase()
        color: Tokens.detail
        font.pointSize: Tokens.pt(9.5)
        font.letterSpacing: 1.2
        font.weight: Font.Medium
    }

    Item {
        id: body

        anchors.top: heading.bottom
        anchors.topMargin: Tokens.headingGap
        anchors.left: parent.left
        anchors.right: parent.right
        height: column.rows * Tokens.rowHeight
            + Math.max(0, column.rows - 1) * Tokens.rowGap
        clip: true

        ListView {
            id: list

            anchors.fill: parent
            model: column.source
            spacing: Tokens.rowGap
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            reuseItems: true

            // The row is a child of a wrapper the list positions, and it
            // leaves that wrapper while it is dragged: reparented to the view
            // itself, so the rows moving underneath it cannot drag it along
            // with them. This is the shape of Qt's own reorderable list.
            delegate: Item {
                id: wrapper

                required property int index
                required property var model

                readonly property bool draggable:
                    column.reorderable && model.pinned === true

                width: list.width
                height: Tokens.rowHeight
                z: rowMouse.drag.active ? 2 : 1

                MenuRow {
                    id: content

                    width: wrapper.width
                    height: Tokens.rowHeight

                    // The wrapper owns the pointer, so the row only draws.
                    interactive: false
                    externalHover: rowMouse.containsMouse

                    accent: column.accent
                    label: wrapper.model.display ?? ""
                    iconSource: wrapper.model.decoration ?? ""
                    detail: column.showDetail ? (wrapper.model.description ?? "") : ""
                    selected: column.selected === wrapper.index
                    // A row may say it cannot be kept — a sum or a web
                    // search has nowhere to live.
                    pinnable: column.pinnable && wrapper.model.pinnable !== false
                    pinned: wrapper.model.pinned === true

                    anchors.horizontalCenter: wrapper.horizontalCenter
                    anchors.verticalCenter: wrapper.verticalCenter

                    Drag.active: rowMouse.drag.active
                    Drag.source: wrapper
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    opacity: rowMouse.drag.active ? 0.9 : 1

                    onPinToggled: column.pinToggled(wrapper.index)

                    states: State {
                        when: rowMouse.drag.active

                        ParentChange {
                            target: content
                            parent: list
                        }

                        AnchorChanges {
                            target: content
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: undefined
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        // Whether this press has turned into a drag. Letting
                        // go of a row that never moved has to stay a click:
                        // committing an order on every release rebuilt the
                        // model under the delegate, and the click that was
                        // about to open the thing went with it.
                        property bool dragged: false

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        drag.target: wrapper.draggable ? content : null
                        drag.axis: Drag.YAxis
                        drag.smoothed: false
                        drag.onActiveChanged: if (drag.active) {
                            rowMouse.dragged = true;
                        }

                        onPressed: rowMouse.dragged = false
                        // MouseArea does not call this one a click if it was
                        // dragged, so opening and reordering never collide.
                        onClicked: column.triggered(wrapper.index)
                        onEntered: column.hovered(wrapper.index)
                        onReleased: if (rowMouse.dragged) {
                            column.dropped();
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent

                    onEntered: drag => {
                        const from = drag.source.index;
                        if (from !== wrapper.index && wrapper.draggable) {
                            column.moved(from, wrapper.index);
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Math.round(Tokens.rowHeight / 2 - height / 2)

            visible: column.emptyText !== "" && list.count === 0
            text: column.emptyText
            color: Tokens.detail
            font.pointSize: Tokens.pt(11.5)
            elide: Text.ElideRight
        }

        QQC2.ScrollBar {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            visible: list.interactive
            size: list.height / Math.max(1, list.contentHeight)
            position: list.visibleArea.yPosition
            active: true
            policy: QQC2.ScrollBar.AlwaysOn

            onPositionChanged: if (pressed) {
                list.contentY = position * list.contentHeight;
            }
        }
    }
}
