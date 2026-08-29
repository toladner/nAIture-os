/*
 * naiture — dock proximity
 *
 * The design's dock rests at 20% and comes up to full as the pointer nears it
 * (naiture-canvas.logic.js: `dockRestOpacity` 0.2, a 720x150 hit box centred on
 * the bottom edge, `transition: opacity .3s ease`). Plasma has no hover state
 * for a panel — panelOpacity is a fixed adaptive/opaque/translucent choice — so
 * the fade is driven from KWin, which owns the panel windows and lets a script
 * write their `opacity`.
 *
 * Panels are layer-shell surfaces rather than managed clients, but they do turn
 * up in the workspace window list as `dock` windows owned by plasmashell, and
 * their opacity is writable.
 *
 * Three things here are easy to get wrong; all three are settled by
 * kwin/src/scripting/workspace_wrapper.h rather than by guessing:
 *
 *   - A *declarative* script reaches the workspace through the `Workspace`
 *     singleton of org.kde.kwin and enumerates with the `windows` property. A
 *     plain-javascript script gets a lowercase `workspace` context object and
 *     enumerates with `windowList()`. Each spelling is undefined in the other
 *     flavour, and this is a declarative script because it needs Timer and
 *     NumberAnimation.
 *   - `Workspace.cursorPos` has a change signal, so the common case costs
 *     nothing: proximity is a binding, not a poll. The timer below is only a
 *     floor on responsiveness in case the signal is quiet, and the refresh that
 *     keeps up with a dock that changed width.
 *   - The dock rects are cached. Rebuilding them inside the cursor binding
 *     would run a full window scan on every pointer motion event.
 *
 * The time island is deliberately left alone; the design keeps it at full
 * opacity always. A dock counts as "the dock" when it sits near the middle of
 * its screen, which is true of the centred switcher island and false of the
 * right-aligned time pill.
 */
import QtQuick
import org.kde.kwin

Item {
    id: root

    // The design's resting opacity for the dock.
    readonly property real restOpacity: 0.2

    // How far outside the dock the pointer still counts as near. The design
    // uses a 720x150 box around a ~600x50 dock: roughly 60px to the sides and
    // 100px above.
    readonly property int nearMarginX: 80
    readonly property int nearMarginY: 110

    // `transition: opacity .3s ease`
    readonly property int fadeMs: 300

    // A dock is the centre island when its middle is within this fraction of
    // the screen width of the screen's middle.
    readonly property real centreTolerance: 0.25

    // Worst-case reaction time if cursorPosChanged stays quiet, and how often
    // the cached dock geometry is refreshed.
    readonly property int refreshMs: 200

    // Re-evaluates whenever the pointer moves.
    readonly property point cursor: Workspace.cursorPos

    // The panels this script owns, and a snapshot of where they are.
    property var docks: []

    property bool near: false

    // One animator for the whole dock: every managed panel fades together.
    property real level: restOpacity

    Behavior on level {
        NumberAnimation {
            duration: root.fadeMs
            easing.type: Easing.InOutQuad
        }
    }

    onCursorChanged: updateNear()
    onNearChanged: root.level = near ? 1.0 : root.restOpacity
    onLevelChanged: apply()

    function refreshDocks() {
        const found = [];
        const windows = Workspace.windows;
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            if (!w.dock || w.resourceName !== "plasmashell") {
                continue;
            }
            const screen = w.output ? w.output.geometry : Workspace.virtualScreenGeometry;
            const screenCentre = screen.x + screen.width / 2;
            const dockCentre = w.frameGeometry.x + w.frameGeometry.width / 2;
            if (Math.abs(dockCentre - screenCentre) <= screen.width * root.centreTolerance) {
                found.push(w);
            }
        }
        root.docks = found;
    }

    function updateNear() {
        const p = root.cursor;
        let hit = false;
        for (let i = 0; i < root.docks.length; i++) {
            const g = root.docks[i].frameGeometry;
            // The margin only grows the box away from the screen edge the dock
            // is anchored to, which for a bottom panel means upwards.
            if (p.x >= g.x - root.nearMarginX
                && p.x <= g.x + g.width + root.nearMarginX
                && p.y >= g.y - root.nearMarginY
                && p.y <= g.y + g.height) {
                hit = true;
                break;
            }
        }
        root.near = hit;
    }

    function apply() {
        for (let i = 0; i < root.docks.length; i++) {
            if (root.docks[i].opacity !== root.level) {
                root.docks[i].opacity = root.level;
            }
        }
    }

    // Keeps up with a panel plasmashell has just recreated (it comes back at
    // full opacity) and with a dock that changed width because a task tile
    // appeared under the resting pointer.
    Timer {
        interval: root.refreshMs
        running: true
        repeat: true
        onTriggered: {
            root.refreshDocks();
            root.updateNear();
            root.apply();
        }
    }

    Component.onCompleted: {
        refreshDocks();
        updateNear();
        apply();
    }
}
