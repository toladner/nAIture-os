/*
 * naiture — the dock.
 *
 * This replaces Plasma's task manager, and the reason is narrow: three things
 * the design asks for are not reachable from outside it.
 *
 *   - The icon greys on hover. taskmanager/qml/Task.qml binds
 *     `Kirigami.Icon.active` to `highlighted`, which is plain
 *     `containsMouse`, and Kirigami feeds that straight into its icon shader as
 *     a hardcoded 0.7 highlight (kirigami/src/primitives/icon.cpp). The
 *     `taskHoverEffect` setting gates only the frame behind the icon. No
 *     config, theme or SVG reaches the uniform.
 *   - Icons cannot grow under the pointer: the task manager sizes each icon to
 *     the panel and there is no scale to animate.
 *   - The active marker is a 9-slice frame swapped per tile, so it can only
 *     appear and disappear. It cannot travel, and it cannot leave its tile to
 *     sit on the island's edge.
 *
 * Everything else still comes from Plasma: `org.kde.taskmanager` is the public
 * QML module behind its own task manager, so the window list, the filtering by
 * desktop, screen and activity, and every request below are the same code its
 * applet uses. What this file owns is only how a task looks and moves.
 *
 * The two panel-applet rules this repo keeps relearning apply here too: the
 * size hints live on the PlasmoidItem rather than on the representation, and an
 * applet that shows itself inline uses `fullRepresentation`.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    readonly property bool horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    // The island's content area: what Plasma gives the applet between the
    // panel background's margins.
    readonly property int contentExtent: {
        const extent = horizontal ? height : width;
        return extent > 0 ? extent : Kirigami.Units.iconSizes.medium;
    }

    // The design's dock spaces its tiles 8px apart.
    readonly property int tileSpacing: 8

    // How far an icon lifts under the pointer. Neighbours stay put: the island
    // is sized to its contents, so growing the row would make the whole island
    // breathe on every hover.
    readonly property real magnification: 1.25

    // An icon lifts from its own baseline, so it needs somewhere to go. All it
    // has is the island's content height plus whatever is left of the margin
    // once the marker and a little daylight are taken out — grow past that and
    // the icon climbs into the marker, which is what a full-height icon did.
    // So the resting size is chosen backwards from the room available.
    readonly property int markerGap: 2
    readonly property int headroom: Math.max(0, islandMargin - markerThickness - markerGap)
    readonly property int iconSize:
        Math.max(8, Math.floor((contentExtent + headroom) / magnification))

    // The marker on the island's edge, and how far the applet sits inside that
    // edge — the panel background's top margin, from tools/make_panel_svg.py.
    // Applets are not clipped, so the marker can reach back out. Keep this in
    // step with MARGIN there.
    readonly property int markerThickness: 3
    readonly property int islandMargin: 7

    readonly property color accent: Kirigami.Theme.highlightColor

    // The rule between the launcher and the running apps. It is drawn here
    // because the launcher is its own applet: this is the dock's leading edge.
    readonly property int separatorWidth: 1
    readonly property int separatorSpacing: 10

    // The hover preview, in the quick-settings sheet's language and — for a
    // single window — at its width.
    readonly property int previewWidth: 400

    // How wide the whole strip of thumbnails is allowed to get, as a multiple
    // of one thumbnail. Sharing a fixed card between n windows makes each 1/n
    // as wide, which is unreadable by three; letting the card grow instead
    // costs width far more slowly. `2 - 2^(1-n)` gives 1x, 1.5x, 1.75x, 1.875x
    // — always widening, never past twice.
    readonly property real previewSpread: 2
    readonly property int previewPadding: 12
    readonly property int previewSpacing: 8
    readonly property int previewRadius: 20

    // The card rises out of the island rather than floating over it: its
    // bottom runs into the island and is squared off, so there is no bottom
    // edge to see — the same shape the islands themselves have.
    readonly property int previewLift: 0

    readonly property int previewLabelHeight: Kirigami.Units.gridUnit

    // The rule wants the same daylight on both sides. On its left that gap is
    // the panel's own spacing between applets — the launcher is a separate
    // applet — plus the margin below; on its right it is only the margin, so
    // the row has to start that much further along.
    readonly property int panelSpacing: Kirigami.Units.smallSpacing

    readonly property int leadIn: horizontal
        ? panelSpacing + separatorSpacing * 2 + separatorWidth
        : 0

    readonly property int contentLength:
        Math.max(1, leadIn + tasksModel.count * iconSize
                 + Math.max(0, tasksModel.count - 1) * tileSpacing)

    Layout.minimumWidth: horizontal ? contentLength : 0
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: horizontal ? 0 : contentLength
    Layout.preferredHeight: Layout.minimumHeight
    Layout.fillHeight: horizontal
    Layout.fillWidth: !horizontal

    preferredRepresentation: fullRepresentation

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        screenGeometry: Plasmoid.containment.screenGeometry

        filterByVirtualDesktop: true
        filterByScreen: true
        filterByActivity: true

        launchInPlace: true
        separateLaunchers: false
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual

        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList
    }

    function indexAt(row: int): var {
        return tasksModel.makeModelIndex(row);
    }

    // Hovering a thumbnail brings its window forward on the desktop, the way
    // Windows peeks at one. KWin's HighlightWindow effect is what does it, and
    // it is the same call Plasma's own task manager makes for its tooltips —
    // pass the windows to raise, or an empty list to let go.
    function highlightWindows(ids: var): void {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.HighlightWindow",
            path: "/org/kde/KWin/HighlightWindow",
            iface: "org.kde.KWin.HighlightWindow",
            member: "highlightWindows",
            arguments: [ids],
            signature: "(as)"
        });
    }

    fullRepresentation: Item {
        id: dock

        // Whichever tile the marker is currently on: the pointer's if it is
        // over one, otherwise the active window's.
        property Item hoveredTile: null
        property Item activeTile: null

        // The preview lags the pointer: it stays up long enough to walk onto,
        // which is what makes a thumbnail clickable.
        property Item previewTile: null
        readonly property alias hideDelay: previewHide

        readonly property Item markedTile: hoveredTile ?? activeTile

        Rectangle {
            id: separator

            visible: root.horizontal
            anchors.left: parent.left
            anchors.leftMargin: root.separatorSpacing
            anchors.verticalCenter: parent.verticalCenter
            width: root.separatorWidth
            height: Math.round(parent.height * 0.55)
            radius: width / 2
            color: "#f2f7f2"
            opacity: 0.18
        }

        Row {
            id: taskRow

            anchors.left: parent.left
            anchors.leftMargin: root.leadIn
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tileSpacing

            Repeater {
                model: tasksModel

                delegate: Item {
                    id: tile

                    required property int index
                    required property var model

                    readonly property bool isActive: model.IsActive === true
                    readonly property bool isMinimized: model.IsMinimized === true
                    readonly property bool isLauncher: model.IsLauncher === true

                    width: root.iconSize
                    height: root.contentExtent

                    onIsActiveChanged: if (isActive) {
                        dock.activeTile = tile;
                    } else if (dock.activeTile === tile) {
                        dock.activeTile = null;
                    }

                    Component.onCompleted: if (isActive) {
                        dock.activeTile = tile;
                    }

                    Component.onDestruction: {
                        if (dock.activeTile === tile) {
                            dock.activeTile = null;
                        }
                        if (dock.hoveredTile === tile) {
                            dock.hoveredTile = null;
                        }
                    }

                    Kirigami.Icon {
                        id: icon

                        // Anchored to the bottom so the lift is upward and the
                        // row of icons keeps one baseline.
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.iconSize
                        height: root.iconSize

                        source: tile.model.decoration

                        // Never Kirigami's hover wash: the lift and the marker
                        // say everything this needs to say.
                        active: false

                        // A window that is only minimised is still open, and
                        // the design draws it dimmer rather than absent.
                        opacity: tile.isLauncher ? 0.55
                               : tile.isMinimized ? 0.65
                               : 1

                        // Grow upward, the way a dock does, rather than out of
                        // both sides into the neighbours.
                        transformOrigin: Item.Bottom
                        scale: pointer.containsMouse ? root.magnification : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                        onEntered: dock.hoveredTile = tile
                        onExited: if (dock.hoveredTile === tile) {
                            dock.hoveredTile = null;
                        }

                        onClicked: mouse => {
                            const modelIndex = root.indexAt(tile.index);
                            if (mouse.button === Qt.MiddleButton) {
                                tasksModel.requestNewInstance(modelIndex);
                            } else if (mouse.button === Qt.RightButton) {
                                taskMenu.popup();
                            } else if (tile.isActive) {
                                tasksModel.requestToggleMinimized(modelIndex);
                            } else {
                                tasksModel.requestActivate(modelIndex);
                            }
                        }
                    }

                    QQC2.Menu {
                        id: taskMenu

                        QQC2.MenuItem {
                            text: i18n("New window")
                            onTriggered: tasksModel.requestNewInstance(root.indexAt(tile.index))
                        }

                        QQC2.MenuItem {
                            text: tile.model.HasLauncher === true
                                ? i18n("Unpin from dock")
                                : i18n("Pin to dock")
                            onTriggered: {
                                const url = tile.model.LauncherUrlWithoutIcon;
                                if (tile.model.HasLauncher === true) {
                                    tasksModel.requestRemoveLauncher(url);
                                } else {
                                    tasksModel.requestAddLauncher(url);
                                }
                            }
                        }

                        QQC2.MenuSeparator {}

                        QQC2.MenuItem {
                            text: i18n("Close")
                            enabled: tile.model.IsClosable === true
                            onTriggered: tasksModel.requestClose(root.indexAt(tile.index))
                        }
                    }
                }
            }
        }

        // Windows shows a live thumbnail rather than the app's name, and so does
        // this. On Wayland there is no pixmap to borrow: a thumbnail is a
        // screencast, requested per window through TaskManager.ScreencastingRequest
        // and rendered by PipeWireSourceItem — the same pair Plasma's own task
        // manager uses (taskmanager/qml/PipeWireThumbnail.qml). The request only
        // exists while the preview is up.
        Timer {
            id: previewDelay
            interval: Kirigami.Units.toolTipDelay
            onTriggered: {
                dock.previewTile = dock.hoveredTile;
                preview.visible = dock.previewTile !== null;
                preview.centreOnTile();
            }
        }

        Timer {
            id: previewHide
            interval: 200
            onTriggered: {
                preview.visible = false;
                dock.previewTile = null;
                root.highlightWindows([]);
            }
        }

        onHoveredTileChanged: {
            if (hoveredTile) {
                previewHide.stop();
                if (preview.visible) {
                    dock.previewTile = hoveredTile;
                    Qt.callLater(preview.centreOnTile);
                } else {
                    previewDelay.restart();
                }
            } else {
                previewDelay.stop();
                previewHide.restart();
            }
        }

        PlasmaCore.Dialog {
            id: preview

            visualParent: dock.previewTile
            location: Plasmoid.location
            type: PlasmaCore.Dialog.Tooltip
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: false
            flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint

            readonly property var task: dock.previewTile ? dock.previewTile.model : null

            // Plasma centres a dialog on its visual parent only until the
            // screen gets in the way; a card several thumbnails wide is exactly
            // the case where it stops. Re-centre it on the icon once Plasma has
            // finished placing it, and keep it on the screen.
            onVisibleChanged: if (visible) {
                Qt.callLater(centreOnTile);
            }

            function centreOnTile(): void {
                const tile = dock.previewTile;
                const output = preview.screen;
                if (!tile || !output) {
                    return;
                }
                const centre = tile.mapToGlobal(tile.width / 2, 0);
                const leftmost = output.virtualX;
                const rightmost = output.virtualX + output.width - preview.width;
                preview.x = Math.round(
                    Math.max(leftmost, Math.min(rightmost, centre.x - preview.width / 2)));
            }

            // With GroupApplications on, a tile can stand for several windows,
            // and a group parent's WinIdList carries every one of them — so two
            // Konsoles get two thumbnails, the way Windows shows them.
            readonly property var windowIds: {
                const ids = preview.task ? preview.task.WinIdList : undefined;
                return ids ?? [];
            }

            readonly property int shotCount: Math.max(1, windowIds.length)

            // One thumbnail's width when it is the only one.
            readonly property int singleShotWidth: root.previewWidth - root.previewPadding * 2

            // What the strip of thumbnails is allowed to occupy, capped so a
            // dozen windows cannot push the card off the screen.
            readonly property int shotsWidth: Math.min(
                singleShotWidth * (root.previewSpread
                                   - Math.pow(2, 1 - shotCount)),
                Plasmoid.containment.screenGeometry.width - root.previewPadding * 2 - 40)

            // With one preview the name says which app this is; with several,
            // the icon above them already has.
            readonly property bool showName: shotCount <= 1
            readonly property int shotWidth:
                (shotsWidth - root.previewSpacing * (shotCount - 1)) / shotCount
            readonly property int shotHeight: Math.round(shotWidth * 9 / 16)

            // The dialog reads mainItem's implicit size early and keeps what it
            // first gets, so this is worked out from numbers the applet already
            // knows rather than from the card inside it — a height that waits
            // for a child arrives as 0 and the card ends up clipped.
            readonly property int cardWidth: shotsWidth + root.previewPadding * 2

            readonly property int cardHeight:
                root.previewPadding * 2 + shotHeight
                + (showName ? root.previewSpacing + root.previewLabelHeight : 0)

            mainItem: Item {
                implicitWidth: preview.cardWidth
                implicitHeight: preview.cardHeight + root.previewLift

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: preview.cardWidth
                    height: preview.cardHeight

                    topLeftRadius: root.previewRadius
                    topRightRadius: root.previewRadius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                    color: Qt.rgba(13 / 255, 24 / 255, 17 / 255, 0.92)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    // Moving onto the preview must not dismiss it, or a
                    // thumbnail could never be clicked.
                    HoverHandler {
                        onHoveredChanged: if (hovered) {
                            dock.hideDelay.stop();
                        } else {
                            dock.hideDelay.restart();
                        }
                    }

                    Column {
                        x: root.previewPadding
                        y: root.previewPadding
                        width: parent.width - root.previewPadding * 2
                        spacing: root.previewSpacing

                        Row {
                            width: parent.width
                            spacing: root.previewSpacing

                            Repeater {
                                model: preview.windowIds

                                delegate: Rectangle {
                                    id: shot

                                    required property var modelData
                                    required property int index

                                    width: preview.shotWidth
                                    height: preview.shotHeight
                                    radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.09)
                                    clip: true

                                    PipeWire.PipeWireSourceItem {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        nodeId: screencast.nodeId

                                        // The screencast only runs while the
                                        // preview is up.
                                        TaskManager.ScreencastingRequest {
                                            id: screencast
                                            uuid: preview.visible ? shot.modelData : ""
                                        }
                                    }

                                    // The same bar the dock puts over the
                                    // active window, so "this one" is said the
                                    // same way in both places.
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 1
                                        height: root.markerThickness
                                        radius: height / 2
                                        color: root.accent
                                        opacity: shotPointer.hovered ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }

                                    HoverHandler {
                                        id: shotPointer

                                        cursorShape: Qt.PointingHandCursor

                                        onHoveredChanged: root.highlightWindows(
                                            hovered ? [shot.modelData] : [])
                                    }

                                    TapHandler {
                                        onTapped: {
                                            // A group's windows are children of
                                            // its row, so a single window and
                                            // one of several are different
                                            // indices.
                                            const taskRowIndex = dock.previewTile.index;
                                            const modelIndex = preview.windowIds.length > 1
                                                ? tasksModel.makeModelIndex(taskRowIndex, shot.index)
                                                : tasksModel.makeModelIndex(taskRowIndex);
                                            tasksModel.requestActivate(modelIndex);
                                            dock.hideDelay.stop();
                                            preview.visible = false;
                                            dock.previewTile = null;
                                            root.highlightWindows([]);
                                        }
                                    }
                                }
                            }
                        }

                        PC3.Label {
                            visible: preview.showName
                            width: parent.width
                            height: root.previewLabelHeight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: preview.task ? (preview.task.AppName ?? "") : ""
                            color: "#f2f7f2"
                        }
                    }
                }
            }
        }

        // One marker for the whole dock, so it travels between tiles instead of
        // blinking out of one and into the next. It rides on the island's top
        // edge rather than the tile's — applets are not clipped, so it may sit
        // outside this one.
        Rectangle {
            id: marker

            visible: dock.markedTile !== null
            y: -root.islandMargin
            height: root.markerThickness
            radius: height / 2
            color: root.accent

            x: dock.markedTile ? taskRow.x + dock.markedTile.x : 0
            width: dock.markedTile ? dock.markedTile.width : 0

            // Dimmer while it is only previewing what the pointer is over.
            opacity: dock.hoveredTile && dock.hoveredTile !== dock.activeTile ? 0.55 : 1

            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }
}
