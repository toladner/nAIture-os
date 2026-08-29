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
 *
 * The fade only earns its keep when there is something behind the dock to see.
 * On a bare desktop it just makes the island look half-broken, so an empty
 * screen holds it at full opacity whatever the pointer is doing: no visible
 * ordinary window on the dock's own output — minimised, shaded and Plasma's own
 * surfaces do not count — or the desktop itself being what KWin has focused,
 * which is what Meta+D leaves behind.
 *
 * An open sheet counts as using the dock even when the pointer has wandered
 * off, and a script cannot ask an applet whether its sheet is up. It does not
 * have to: the sheet is a plasmashell window sitting on the island, so any
 * plasmashell surface that is not itself a panel and overlaps the dock's
 * hit box — the start sheet, a window preview — holds the island up.
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

    // Nothing to hide behind: no visible ordinary window on the dock's screen.
    property bool screenClear: true

    // One animator for the whole dock: every managed panel fades together.
    property real level: restOpacity

    Behavior on level {
        NumberAnimation {
            duration: root.fadeMs
            easing.type: Easing.InOutQuad
        }
    }

    onCursorChanged: updateNear()
    onNearChanged: updateLevel()
    onScreenClearChanged: updateLevel()
    onLevelChanged: apply()

    function updateLevel() {
        root.level = (root.near || root.screenClear) ? 1.0 : root.restOpacity;
    }

    // A window counts as covering the desktop only if it is an ordinary one the
    // user can see: `normalWindow` drops docks, menus and notifications, and
    // `hidden` covers minimised as well as the windows KWin keeps out of sight.
    function coversDesktop(w, output) {
        if (!w.normalWindow || w.hidden || w.minimized || w.skipTaskbar) {
            return false;
        }
        if (output && w.output && w.output !== output) {
            return false;
        }
        return w.onAllDesktops || !w.desktops || w.desktops.length === 0
            || w.desktops.indexOf(Workspace.currentDesktop) !== -1;
    }

    function updateScreenClear() {
        // "Show desktop" is invisible to a script otherwise. Meta+D leaves
        // every window's geometry, `minimized` and `hidden` exactly as they
        // were — the effect only stops drawing them — and KWin 6.7's
        // declarative Workspace has no showingDesktop of its own; that lives
        // on the org.kde.KWin D-Bus interface, which a KWin script cannot
        // reach. What does change is the focus: KWin activates the desktop
        // window itself. So an active desktop window is how this reads "the
        // desktop is what is in front", which is also true, and just as
        // wanted, when someone clicks the wallpaper.
        const active = Workspace.activeWindow;
        if (active && active.desktopWindow) {
            root.screenClear = true;
            return;
        }

        const windows = Workspace.windows;
        for (let i = 0; i < root.docks.length; i++) {
            const output = root.docks[i].output;
            for (let j = 0; j < windows.length; j++) {
                if (coversDesktop(windows[j], output)) {
                    root.screenClear = false;
                    return;
                }
            }
        }
        root.screenClear = true;
    }

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
            if (popupOver(g)) {
                hit = true;
                break;
            }
        }
        root.near = hit;
    }

    // Is one of plasmashell's own popups standing on this dock? Panels are
    // excluded by `dock`, and so is anything belonging to another process, so
    // what is left is the sheets and previews the island itself put there.
    function popupOver(g) {
        const windows = Workspace.windows;
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            if (w.dock || w.desktopWindow || w.resourceName !== "plasmashell" || w.hidden) {
                continue;
            }
            const r = w.frameGeometry;
            if (r.width <= 0 || r.height <= 0) {
                continue;
            }
            if (r.x <= g.x + g.width + root.nearMarginX
                && r.x + r.width >= g.x - root.nearMarginX
                && r.y <= g.y + g.height
                && r.y + r.height >= g.y - root.nearMarginY) {
                return true;
            }
        }
        return false;
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
            root.updateScreenClear();
            root.updateLevel();
            root.apply();
        }
    }

    Component.onCompleted: {
        refreshDocks();
        updateNear();
        updateScreenClear();
        updateLevel();
        apply();
    }
}
