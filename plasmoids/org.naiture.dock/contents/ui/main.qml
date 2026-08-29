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

    // The hover preview, in the sheet's language.
    readonly property int previewWidth: 240
    readonly property int previewPadding: 10
    readonly property int previewRadius: 14

    // The same daylight the quick-settings sheet keeps above the island.
    readonly property int previewLift: 4 + islandMargin

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

    fullRepresentation: Item {
        id: dock

        // Whichever tile the marker is currently on: the pointer's if it is
        // over one, otherwise the active window's.
        property Item hoveredTile: null
        property Item activeTile: null

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
            onTriggered: preview.visible = dock.hoveredTile !== null
        }

        onHoveredTileChanged: {
            if (hoveredTile) {
                previewDelay.restart();
            } else {
                previewDelay.stop();
                preview.visible = false;
            }
        }

        PlasmaCore.Dialog {
            id: preview

            visualParent: dock.hoveredTile
            location: Plasmoid.location
            type: PlasmaCore.Dialog.Tooltip
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: false
            flags: Qt.WindowTransparentForInput | Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint

            readonly property var task: dock.hoveredTile ? dock.hoveredTile.model : null
            readonly property var windowId: {
                const ids = preview.task ? preview.task.WinIdList : undefined;
                return ids && ids.length > 0 ? ids[0] : undefined;
            }

            mainItem: Item {
                implicitWidth: root.previewWidth
                implicitHeight: card.height + root.previewLift

                Rectangle {
                    id: card

                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: root.previewWidth
                    height: column.implicitHeight + root.previewPadding * 2

                    radius: root.previewRadius
                    color: Qt.rgba(13 / 255, 24 / 255, 17 / 255, 0.92)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    Column {
                        id: column

                        x: root.previewPadding
                        y: root.previewPadding
                        width: card.width - root.previewPadding * 2
                        spacing: 8

                        Rectangle {
                            width: parent.width
                            height: Math.round(width * 9 / 16)
                            visible: preview.windowId !== undefined
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.05)
                            clip: true

                            PipeWire.PipeWireSourceItem {
                                anchors.fill: parent
                                nodeId: screencast.nodeId

                                TaskManager.ScreencastingRequest {
                                    id: screencast
                                    uuid: preview.visible ? (preview.windowId ?? "") : ""
                                }
                            }
                        }

                        PC3.Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
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
