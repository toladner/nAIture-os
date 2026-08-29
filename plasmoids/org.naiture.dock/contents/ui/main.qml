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
 * The mark is the row's first tile rather than a launcher applet of its own,
 * and it has to be: the accent bar is one Rectangle that slides between tiles,
 * and two applets are two coordinate spaces with a panel layout in between. As
 * a tile it is marked, hovered and lifted by exactly the code the windows use.
 * The design draws the same thing — start, rule and tasks are one container in
 * design/naiture-canvas.dc.html, not three.
 *
 * X-Plasma-Provides: org.kde.plasma.launchermenu in metadata.json is what lets
 * the Meta key reach the sheet: plasmashell's activateLauncherMenu looks for an
 * applet that provides it and activates that one.
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
    //
    // This is also what decides how full the island looks, and the two pull
    // against each other. An icon lifts from its resting size into the room
    // above it, so whatever it is allowed to grow by, it has to rest that much
    // below the island's content height — and that reserve is empty every
    // moment the pointer is elsewhere, which is most of them. At 1.25 the icon
    // rested at 24px in a 42px island, 57% of it, against the design's 34-in-50
    // ratio of 68%; the island read as tall because it was mostly holding room
    // for a hover. 1.12 puts the resting icon at 26px and still lifts it to 29.
    readonly property real magnification: 1.12

    // An icon lifts from its own baseline, so it needs somewhere to go. All it
    // has is the island's content height plus whatever is left of the top
    // margin once a marker's worth of daylight is kept between the icon and
    // the island's edge — grow past that and a lifted icon runs off the
    // island, which is what a full-height icon did. So the resting size is
    // chosen backwards from the room available.
    // The marker sits on the island's *bottom* edge, so the top margin has no
    // marker to keep clear of — only a little daylight between the lifted icon
    // and the island's edge. Subtracting the marker's thickness up here as
    // well left the icon resting 3px smaller than the island had room for, and
    // that 3px was empty above it every moment nothing was hovered.
    readonly property int markerGap: 2
    readonly property int headroom: Math.max(0, islandMargin - markerGap)
    readonly property int iconSize:
        Math.max(8, Math.floor((contentExtent + headroom) / magnification))

    // The marker on the island's bottom edge, and how far the applet sits
    // inside that edge — the panel background's margin, from
    // tools/make_panel_svg.py.
    // Applets are not clipped, so the marker can reach back out. Keep this in
    // step with MARGIN there.
    readonly property int markerThickness: 3
    readonly property int islandMargin: 7

    readonly property color accent: Kirigami.Theme.highlightColor

    // The rule between the mark and the running apps. It sits in the row as a
    // tile of its own so the daylight either side of it is the row's spacing
    // plus whatever this adds — equal on both sides by construction.
    readonly property int separatorWidth: 1
    readonly property int separatorSpacing: 10
    readonly property int separatorBlock:
        separatorWidth + Math.max(0, separatorSpacing - tileSpacing) * 2

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

    // The close button in a thumbnail's corner.
    readonly property int previewCloseSize: 18

    // Daylight at each end of the row, so the mark stands off the island's
    // left edge by as much as the last window stands off its right. Without it
    // the island is symmetrical only while something is running: with no
    // windows the rule and its spacing are gone from the row but were still
    // counted here, which left the whole gap sitting on the right of the mark.
    // Six is that gap halved, so an empty island keeps the width it had.
    readonly property int edgePad: 6

    // …and the island is not symmetrical either, so the two pads are not
    // equal. Plasma's panel layout keeps a fill spacer after the last applet
    // (containments/panel/main.qml, the workaround for BUG 454095) and the
    // GridLayout's columnSpacing between the applet and that spacer is counted
    // into the width a fitted panel asks for. The spacer itself is empty and
    // sits at the end, so a centred island is one smallSpacing wider on the
    // right than on the left — measured here as 6px of panel left of the
    // applet and 10px right of it. Give that much back from the right pad and
    // the two visible margins come out level.
    readonly property int trailingSlack: Kirigami.Units.smallSpacing
    readonly property int leadingPad: edgePad
    readonly property int trailingPad: Math.max(0, edgePad - trailingSlack)

    // mark | rule | one tile per window, with the row's spacing between each —
    // and no rule at all when there is nothing for it to separate.
    readonly property bool hasTasks: tasksModel.count > 0
    readonly property int tileCount: tasksModel.count + (hasTasks ? 2 : 1)

    readonly property int contentLength:
        Math.max(1, leadingPad + trailingPad
                 + iconSize * (1 + tasksModel.count)
                 + (hasTasks ? separatorBlock : 0)
                 + Math.max(0, tileCount - 1) * tileSpacing)

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

    // A group's windows are children of its row, so one of several and a lone
    // window are different indices. Both the preview's click and its close
    // button need this.
    function windowIndex(row: int, child: int, count: int): var {
        return count > 1 ? tasksModel.makeModelIndex(row, child)
                         : tasksModel.makeModelIndex(row);
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

    // Meta, or a shortcut assigned in System Settings, arrives here.
    Connections {
        target: Plasmoid

        function onActivated() {
            root.toggleStart();
        }
    }

    function toggleStart(): void {
        start.visible = !start.visible;
    }

    StartSheet {
        id: start

        visualParent: root
        accent: root.accent
        applet: Plasmoid
        edge: Plasmoid.location
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

        // The tile whose sheet is open outranks the active window: while the
        // start sheet is up, the bar belongs to the mark.
        readonly property Item markedTile:
            hoveredTile ?? (start.visible ? markTile : null) ?? activeTile

        Row {
            id: taskRow

            // Left, at the leading pad: the two pads differ on purpose, so
            // centring the row here would undo the correction above.
            anchors.left: parent.left
            anchors.leftMargin: root.leadingPad
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tileSpacing

            // The mark. It is a tile like any other, which is the whole point:
            // the bar slides onto it, it lifts under the pointer, and it sits
            // on the same baseline as the windows beside it.
            Item {
                id: markTile

                width: root.iconSize
                height: root.contentExtent

                // fullRepresentation is a Component, so the sheet cannot be
                // handed this tile from the root scope; it takes it from here.
                Component.onCompleted: start.anchorItem = markTile

                Component.onDestruction: if (dock.hoveredTile === markTile) {
                    dock.hoveredTile = null;
                }

                Image {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.iconSize
                    height: root.iconSize

                    source: Qt.resolvedUrl("../icons/naiture.svg")
                    sourceSize.width: root.iconSize * 2
                    sourceSize.height: root.iconSize * 2
                    smooth: true

                    scale: markPointer.containsMouse || start.visible
                        ? root.magnification : 1
                    transformOrigin: Item.Bottom

                    Behavior on scale {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    id: markPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: dock.hoveredTile = markTile
                    onExited: if (dock.hoveredTile === markTile) {
                        dock.hoveredTile = null;
                    }
                    onClicked: {
                        startDelay.stop();
                        root.toggleStart();
                    }
                }
            }

            // The rule. It is a tile too, so the row spaces it like everything
            // else and it never has to be positioned by hand — and a Row skips
            // a hidden child's spacing as well, so with nothing to separate it
            // leaves no gap behind: no windows, no rule.
            Item {
                visible: root.horizontal && root.hasTasks
                width: root.separatorBlock
                height: root.contentExtent

                Rectangle {
                    anchors.centerIn: parent
                    width: root.separatorWidth
                    height: Math.round(parent.height * 0.55)
                    radius: width / 2
                    color: "#f2f7f2"
                    opacity: 0.18
                }
            }

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
                        if (dock.previewTile === tile) {
                            dock.previewTile = null;
                            preview.visible = false;
                            root.highlightWindows([]);
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

                        // Kirigami rounds a themed icon down to the nearest
                        // size the theme actually ships — 16, 22, 24, 32 — and
                        // draws that pixmap centred in whatever item it was
                        // given. Asking for 29 therefore drew 22 inside 29, so
                        // every window's icon sat in a box a third bigger than
                        // itself while the mark, which is an Image and honours
                        // the size it is handed, filled its own. It read as the
                        // mark being too large; it was the only one at full
                        // size. The island's height is chosen backwards from
                        // the room available and is not a size any theme ships,
                        // so the rounding has to go.
                        roundToIconSize: false

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

        // The mark has no window behind it, so what it opens on hover is the
        // sheet — a thumbnail of nothing was what it did before.
        Timer {
            id: startDelay

            // Short enough to feel like hovering opens it, long enough that
            // crossing the mark on the way to an app icon does not.
            interval: 120
            onTriggered: start.visible = true
        }

        onHoveredTileChanged: {
            startDelay.stop();

            if (hoveredTile === markTile) {
                previewDelay.stop();
                previewHide.restart();
                if (!start.visible) {
                    startDelay.restart();
                }
                return;
            }

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

                                    // The thumbnail and its close button each
                                    // take the pointer from the other, so both
                                    // read one state rather than their own.
                                    readonly property bool over:
                                        shotPointer.hovered || closeArea.containsMouse

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
                                        opacity: shot.over ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }

                                    HoverHandler {
                                        id: shotPointer

                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    onOverChanged: root.highlightWindows(
                                        over ? [shot.modelData] : [])

                                    // Windows puts a close on the preview, not
                                    // just in the menu behind the icon. It is a
                                    // MouseArea rather than a TapHandler so the
                                    // click stops here instead of also raising
                                    // the window underneath it.
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 4

                                        width: root.previewCloseSize
                                        height: root.previewCloseSize
                                        radius: height / 2

                                        // The palette's close affordance,
                                        // palette/naiture.json accent.ember.
                                        color: closeArea.containsMouse
                                            ? Qt.rgba(242 / 255, 113 / 255, 106 / 255, 0.95)
                                            : Qt.rgba(0, 0, 0, 0.5)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.18)

                                        opacity: shot.over ? 1 : 0
                                        visible: opacity > 0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: Math.round(parent.width * 0.55)
                                            height: width
                                            source: "window-close-symbolic"
                                            color: "#f2f7f2"
                                            isMask: true
                                            active: false
                                        }

                                        MouseArea {
                                            id: closeArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                root.highlightWindows([]);
                                                tasksModel.requestClose(
                                                    root.windowIndex(dock.previewTile.index,
                                                                     shot.index,
                                                                     preview.windowIds.length));
                                            }
                                        }
                                    }

                                    TapHandler {
                                        onTapped: {
                                            tasksModel.requestActivate(
                                                root.windowIndex(dock.previewTile.index,
                                                                 shot.index,
                                                                 preview.windowIds.length));
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
        // blinking out of one and into the next. It rides on the island's
        // bottom edge rather than the tile's — applets are not clipped, so it
        // may sit outside this one.
        Rectangle {
            id: marker

            visible: dock.markedTile !== null
            y: dock.height + root.islandMargin - root.markerThickness
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
