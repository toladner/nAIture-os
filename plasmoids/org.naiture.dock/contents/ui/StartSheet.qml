/*
 * The start sheet: the same object as the quick-settings sheet, at the other
 * end of the island. A search field over three columns — what is pinned, what
 * was opened lately, and which Claude Code sessions are still worth going back
 * to — and, as soon as anything is typed, a list of suggestions with one extra
 * way out at the bottom: hand the line to Claude instead.
 *
 * It is a PlasmaCore.Dialog and not Plasmoid.expanded, for the reason the
 * quick-settings sheet is: on 6.7 the applet popup paints an opaque background
 * of its own that no theme file and no backgroundHints reach, so a rounded
 * rectangle drawn inside only puts fake corners in a square box.
 *
 * What it lists is mostly Plasma's: org.kde.plasma.private.kicker is the module
 * behind Kickoff and Kicker, so the pinned applications and the search are its
 * code. Two columns are ours, and both are a read of something the system
 * already keeps — the Claude Code transcripts for the sessions
 * (contents/code/sessions.py) and the XDG recently-used list for the files
 * (recent.js). Kicker's RecentUsageModel was the obvious source for the second
 * and is not used, because it reads kactivitymanagerd's resource scores, which
 * hold folders and applications on this desktop but no documents at all.
 */
import QtCore
import QtQml
import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions as PlasmaSessions

import "claude.js" as Claude
import "recent.js" as Recent

Sheet {
    id: sheet

    property color accent: Kirigami.Theme.highlightColor

    // `Plasmoid` is attached to the PlasmoidItem and reaches no further, so
    // the two things this file needs from it are handed over instead.
    property var applet: null
    property int edge: PlasmaCore.Types.BottomEdge

    // Konsole profile for a Claude window; scripts/claude-console.sh writes it.
    readonly property string consoleProfile: "Claude"

    readonly property string home:
        StandardPaths.writableLocation(StandardPaths.HomeLocation)
            .toString().replace("file://", "")

    // Asked questions are throwaway, so they run in a directory of their own
    // and that directory is then excluded from the recent list. Claude Code has
    // no way to not write history; keeping it somewhere of its own is the next
    // best thing, and it also means an ask never lands in a real project.
    readonly property string askDir: home + "/.cache/naiture/ask"

    // "Welcome, Tobias": the first word of the name the account carries, and
    // the login name if it carries none.
    readonly property string firstName: {
        const full = (user.fullName ?? "").trim();
        if (full !== "") {
            return full.split(" ")[0];
        }
        return user.loginName ?? "";
    }

    location: sheet.edge

    // The design's 660px sheet, as tall as its one fixed layout needs.
    sheetWidth: Tokens.sheetWidth
    sheetHeight: Tokens.sheetPadY * 2 + Tokens.headerHeight + Tokens.headerGap
        + Tokens.searchHeight + Tokens.sectionGap
        + Tokens.headingHeight + Tokens.headingGap + bodyHeight
        + Tokens.askGap + Tokens.askHeight

    onOpened: {
        reload();
        requestActivate();
        search.forceActiveFocus();
    }

    onClosed: {
        search.text = "";
        selected = -1;
        powerMenu.visible = false;
    }


    // --- what the sheet lists -------------------------------------------

    readonly property string query: search.text.trim()
    readonly property bool searching: query !== ""

    // With mergeResults the runner model holds a single child model of every
    // hit, so the list binds to that rather than to the runner rows.
    readonly property var results: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    // Two things answer a query — KRunner, and the AI tasks read off disk —
    // and they answer into one list, the way an application and a file already
    // sit side by side in KRunner's own results. There is no concatenating
    // proxy model in QML, so KRunner's rows are copied into `found` as they
    // arrive; `harvest` below is what reads them without having to know its
    // role numbers. Each row remembers where it came from.
    readonly property int resultCount: found.count

    // Matching tasks lead, and only a few of them: a task matches only when
    // what was typed is in its title or its project, which is a stronger thing
    // to have meant than the tail of a file search.
    readonly property int taskLimit: 3

    // -1 is the question: nothing in the list is picked, so Enter asks Claude.
    property int selected: -1

    onQueryChanged: {
        selected = -1;
        rebuildResults();
        rebuildColumns();
    }

    // --- what is kept, and what was merely used ---------------------------
    //
    // Every column reads the same way: the things kept, in the order they were
    // put there, and under them the things lately used. Applications are kept
    // in Kickoff's own favourites — so a pin here is a pin there, and anything
    // already pinned there arrives pinned — while files and tasks are kept in
    // this applet's config, since nothing in Plasma has an opinion about them.

    property var pinnedFiles: []
    property var pinnedTasks: []

    function readPins(text): var {
        try {
            const parsed = JSON.parse(text || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    function loadPins(): void {
        pinnedFiles = readPins(applet.configuration.pinnedFiles);
        pinnedTasks = readPins(applet.configuration.pinnedTasks);
    }

    function savePins(): void {
        applet.configuration.pinnedFiles = JSON.stringify(pinnedFiles);
        applet.configuration.pinnedTasks = JSON.stringify(pinnedTasks);
        rebuildColumns();
    }

    // KRunner hands back urls; only the local ones name something that can be
    // kept, and they are kept as plain paths, the way the recent list has them.
    function localPath(url: string): string {
        if (!url) {
            return "";
        }
        if (url.indexOf("file://") === 0) {
            return decodeURIComponent(url.substring("file://".length));
        }
        return url.indexOf("/") === 0 ? url : "";
    }

    function pinnedFileAt(path: string): int {
        for (let i = 0; i < pinnedFiles.length; i++) {
            if (pinnedFiles[i].path === path) {
                return i;
            }
        }
        return -1;
    }

    function pinnedTaskAt(id: string): int {
        for (let i = 0; i < pinnedTasks.length; i++) {
            if (pinnedTasks[i].sessionId === id) {
                return i;
            }
        }
        return -1;
    }

    // Each column is one list: kept rows first, then recent ones that are not
    // already kept. A row remembers which model it came from, because that is
    // what running it needs.
    function rebuildColumns(): void {
        // A column shows what it can show: it is exactly as tall as the sheet
        // allows and nothing scrolls, so the recent rows fill whatever the
        // kept ones leave. Kept rows are never dropped — pinning is a promise.
        const room = Tokens.maxRows;

        // Kept applications are named by whatever id Kickoff filed them under
        // and the recent list may name the same application differently, so
        // the name is checked too: a row the user cannot tell apart from one
        // above it is a duplicate whatever its id says.
        appRows.clear();
        const keptIds = {};
        const keptNames = {};
        for (let i = 0; i < keptApps.count; i++) {
            const app = keptApps.objectAt(i);
            if (!app) {
                continue;
            }
            keptIds[app.favoriteId] = true;
            keptNames[app.display.toLowerCase()] = true;
            appRows.append({
                display: app.display,
                decoration: app.decoration,
                description: "",
                pinned: true,
                favoriteId: app.favoriteId,
                recent: false,
                row: i
            });
        }
        for (let i = 0; i < usedApps.count && appRows.count < room; i++) {
            const app = usedApps.objectAt(i);
            if (!app || keptIds[app.favoriteId] === true
                || keptNames[app.display.toLowerCase()] === true
                || rootModel.favoritesModel.isFavorite(app.favoriteId)) {
                continue;
            }
            appRows.append({
                display: app.display,
                decoration: app.decoration,
                description: "",
                pinned: false,
                favoriteId: app.favoriteId,
                recent: true,
                row: i
            });
        }

        fileRows.clear();
        for (const pin of pinnedFiles) {
            fileRows.append({
                display: pin.display,
                decoration: pin.decoration,
                description: pin.description ?? "",
                pinned: true,
                path: pin.path
            });
        }
        for (let i = 0; i < recentFiles.count && fileRows.count < room; i++) {
            const file = recentFiles.get(i);
            if (pinnedFileAt(file.path) >= 0) {
                continue;
            }
            fileRows.append({
                display: file.display,
                decoration: file.decoration,
                description: file.description,
                pinned: false,
                path: file.path
            });
        }

        taskRows.clear();
        for (const pin of pinnedTasks) {
            taskRows.append({
                display: pin.display,
                decoration: "naiture-claude",
                description: "",
                pinned: true,
                sessionId: pin.sessionId,
                project: pin.project
            });
        }
        for (let i = 0; i < sessions.count && taskRows.count < room; i++) {
            const task = sessions.get(i);
            if (pinnedTaskAt(task.sessionId) >= 0) {
                continue;
            }
            taskRows.append({
                display: task.display,
                decoration: task.decoration,
                description: "",
                pinned: false,
                sessionId: task.sessionId,
                project: task.project
            });
        }
    }

    // --- running a row ----------------------------------------------------

    function openApp(index: int): void {
        const row = appRows.get(index);
        if (!row) {
            return;
        }
        sheet.visible = false;
        if (row.recent) {
            recentApps.trigger(row.row, "", null);
        } else {
            rootModel.favoritesModel.trigger(row.row, "", null);
        }
    }

    function openPath(index: int): void {
        const row = fileRows.get(index);
        if (!row) {
            return;
        }
        sheet.visible = false;
        // Started beside plasmashell rather than under it; see Claude.detached.
        runner.exec(Claude.detached("xdg-open " + Claude.shellQuote(row.path)));
    }

    function resumeTask(index: int): void {
        const row = taskRows.get(index);
        if (!row) {
            return;
        }
        sheet.visible = false;
        runner.exec(Claude.resumeCommand(
            { project: row.project, sessionId: row.sessionId }, consoleProfile));
    }

    // --- keeping a row, and putting the kept ones in order ----------------

    function toggleApp(index: int): void {
        const row = appRows.get(index);
        if (!row || row.favoriteId === "") {
            return;
        }
        if (row.pinned) {
            rootModel.favoritesModel.removeFavorite(row.favoriteId);
        } else {
            rootModel.favoritesModel.addFavorite(row.favoriteId);
        }
    }

    function toggleFile(index: int): void {
        const row = fileRows.get(index);
        if (!row) {
            return;
        }
        const at = pinnedFileAt(row.path);
        const kept = pinnedFiles.slice();
        if (at >= 0) {
            kept.splice(at, 1);
        } else {
            kept.push({
                path: row.path,
                display: row.display,
                decoration: row.decoration,
                description: row.description
            });
        }
        pinnedFiles = kept;
        savePins();
    }

    function toggleTask(index: int): void {
        const row = taskRows.get(index);
        if (!row) {
            return;
        }
        const at = pinnedTaskAt(row.sessionId);
        const kept = pinnedTasks.slice();
        if (at >= 0) {
            kept.splice(at, 1);
        } else {
            kept.push({
                sessionId: row.sessionId,
                project: row.project,
                display: row.display
            });
        }
        pinnedTasks = kept;
        savePins();
    }

    // A drag has finished: the rows are already in their new order, so the
    // stores are rewritten to match what the column now shows.
    function commitApps(): void {
        const ids = [];
        for (let i = 0; i < appRows.count; i++) {
            const row = appRows.get(i);
            if (row.pinned) {
                ids.push(row.favoriteId);
            }
        }
        rootModel.favoritesModel.favorites = ids;
    }

    function commitFiles(): void {
        const kept = [];
        for (let i = 0; i < fileRows.count; i++) {
            const row = fileRows.get(i);
            if (row.pinned) {
                kept.push({
                    path: row.path,
                    display: row.display,
                    decoration: row.decoration,
                    description: row.description
                });
            }
        }
        pinnedFiles = kept;
        savePins();
    }

    function commitTasks(): void {
        const kept = [];
        for (let i = 0; i < taskRows.count; i++) {
            const row = taskRows.get(i);
            if (row.pinned) {
                kept.push({
                    sessionId: row.sessionId,
                    project: row.project,
                    display: row.display
                });
            }
        }
        pinnedTasks = kept;
        savePins();
    }

    // Titles and the project a task ran in, matched the way anyone types:
    // case-insensitively, on any part of either.
    function rebuildResults(): void {
        found.clear();
        if (!searching) {
            return;
        }
        const needle = query.toLowerCase();
        let tasks = 0;
        for (let i = 0; i < sessions.count && tasks < taskLimit
                        && found.count < Tokens.maxRows; i++) {
            const entry = sessions.get(i);
            if (entry.display.toLowerCase().indexOf(needle) === -1
                && entry.description.toLowerCase().indexOf(needle) === -1) {
                continue;
            }
            found.append({
                display: entry.display,
                decoration: entry.decoration,
                // The name says which task this is; the folder it ran in only
                // repeats it. It is still what the query is matched against.
                description: "",
                task: i,
                runner: -1,
                path: "",
                favoriteId: "",
                pinnable: true,
                pinned: pinnedTaskAt(entry.sessionId) >= 0
            });
            tasks++;
        }
        for (let i = 0; i < harvest.count && found.count < Tokens.maxRows; i++) {
            const row = harvest.objectAt(i);
            if (!row) {
                continue;
            }
            const path = localPath(row.url);
            found.append({
                display: row.display,
                decoration: row.decoration,
                description: row.description,
                task: -1,
                runner: i,
                path: path,
                favoriteId: row.favoriteId,
                // Only what can be kept offers a pin: an application, a file
                // or a folder. A sum, a unit conversion or a web search is a
                // one-off and says nothing about where it would live.
                pinnable: row.favoriteId !== "" || path !== "",
                pinned: row.favoriteId !== ""
                    ? rootModel.favoritesModel.isFavorite(row.favoriteId)
                    : (path !== "" && pinnedFileAt(path) >= 0)
            });
        }
    }

    // --- reading and running --------------------------------------------

    // QML's XMLHttpRequest refuses file:// unless QML_XHR_ALLOW_FILE_READ is set
    // in plasmashell's environment, which is not a thing a theme should be
    // doing to a session. The executable engine reads them instead.
    readonly property string recentPath: home + "/.local/share/recently-used.xbel"

    // Shipped beside this file, so it moves with the applet.
    readonly property string sessionsTool:
        Qt.resolvedUrl("../code/sessions.py").toString().replace("file://", "")

    function reload(): void {
        loadPins();
        recentApps.refresh();
        reader.connectSource("python3 " + Claude.shellQuote(sessionsTool)
            + " --exclude " + Claude.shellQuote(askDir)
            + " --limit " + (Tokens.maxRows * 2));
        reader.connectSource("cat " + Claude.shellQuote(recentPath));
    }

    function loadRecent(text: string): void {
        recentFiles.clear();
        for (const file of Recent.parseXbel(text, home, Tokens.maxRows * 2)) {
            recentFiles.append({
                display: file.name,
                decoration: file.icon,
                description: file.where,
                path: file.path
            });
        }
        rebuildColumns();
    }

    function loadSessions(text: string): void {
        sessions.clear();
        let entries = [];
        try {
            entries = JSON.parse(text);
        } catch (e) {
            return;
        }
        for (const entry of entries) {
            sessions.append({
                display: entry.title,
                decoration: "naiture-claude",
                description: Claude.projectName(entry.project),
                sessionId: entry.id,
                project: entry.project
            });
        }
        rebuildResults();
    }

    function run(model, index: int): void {
        if (!model || index < 0 || index >= model.count) {
            return;
        }
        sheet.visible = false;
        model.trigger(index, "", null);
    }

    function resume(index: int): void {
        const entry = sessions.get(index);
        if (!entry) {
            return;
        }
        sheet.visible = false;
        runner.exec(Claude.resumeCommand(entry, consoleProfile));
    }

    // Keeping something straight out of the results: whichever kind it is, it
    // ends up in the same store the column it belongs to reads.
    function toggleFound(index: int): void {
        const row = found.get(index);
        if (!row || !row.pinnable) {
            return;
        }
        if (row.task >= 0) {
            const task = sessions.get(row.task);
            const at = pinnedTaskAt(task.sessionId);
            const tasks = pinnedTasks.slice();
            if (at >= 0) {
                tasks.splice(at, 1);
            } else {
                tasks.push({
                    sessionId: task.sessionId,
                    project: task.project,
                    display: task.display
                });
            }
            pinnedTasks = tasks;
            savePins();
        } else if (row.favoriteId !== "") {
            if (rootModel.favoritesModel.isFavorite(row.favoriteId)) {
                rootModel.favoritesModel.removeFavorite(row.favoriteId);
            } else {
                rootModel.favoritesModel.addFavorite(row.favoriteId);
            }
        } else {
            const at = pinnedFileAt(row.path);
            const files = pinnedFiles.slice();
            if (at >= 0) {
                files.splice(at, 1);
            } else {
                files.push({
                    path: row.path,
                    display: row.display,
                    decoration: row.decoration,
                    description: row.description
                });
            }
            pinnedFiles = files;
            savePins();
        }
        rebuildResults();
    }

    // A found row stands either for a row of KRunner's model or for one of
    // `sessions`; it says which.
    function take(index: int): void {
        const row = found.get(index);
        if (!row) {
            return;
        }
        if (row.task >= 0) {
            resume(row.task);
        } else {
            run(results, row.runner);
        }
    }

    function openSettings(): void {
        sheet.visible = false;
        runner.exec(Claude.detached("systemsettings"));
    }

    function ask(): void {
        const question = sheet.query;
        if (question === "") {
            return;
        }
        sheet.visible = false;
        runner.exec(Claude.askCommand(question, askDir, consoleProfile));
    }

    // Enter takes whatever the keyboard is standing on; with nothing picked it
    // takes the line itself and asks.
    function accept(): void {
        if (selected < 0) {
            ask();
        } else {
            take(selected);
        }
    }

    // The keyboard walks a ring, because the question is a row like the others
    // — it just happens to be the bottom one. Reading down the sheet that is
    // result 0 … result n-1, then the question, so Down from the field enters
    // the list at the top and Up enters it at the bottom, which is the row
    // nearest the field. Either end carries on round rather than stopping at a
    // row with somewhere obvious to go.
    function step(by: int): void {
        if (!searching) {
            return;
        }
        // The question sits at the end of the ring; -1 is how it is spelled
        // everywhere else, so translate at both edges.
        const total = resultCount + 1;
        const at = selected < 0 ? resultCount : selected;
        const next = ((at + by) % total + total) % total;
        selected = next === resultCount ? -1 : next;
    }

    // --- size -------------------------------------------------------------
    //
    // A PlasmaCore.Dialog reads mainItem's *implicit* size and assigns the real
    // one back, so nothing inside may set its own width and height and nothing
    // outside may wait on a child to report one — a binding that resolves to 0
    // first leaves a 0x0 window that never appears. Every number below comes
    // from Tokens and from model counts.

    // The sheet is one size, always. A PlasmaCore.Dialog takes the size it is
    // first given and will not grow later, so a sheet that got taller the
    // moment someone typed — the question row appearing under the results —
    // kept the window it opened at and had its own bottom cut off. Both states
    // are therefore drawn inside the same fixed height: the full list, and the
    // question's strip below it, reserved whether or not it is showing.
    readonly property int visibleRows: Tokens.maxRows

    readonly property int bodyHeight:
        visibleRows * Tokens.rowHeight + Math.max(0, visibleRows - 1) * Tokens.rowGap

    component IconButton: Rectangle {
        id: button

        property string source: ""
        property bool on: false

        signal clicked()

        width: Tokens.headerButton
        height: Tokens.headerButton
        radius: Tokens.rowRadius
        color: pointer.containsMouse || on ? Tokens.rowHover : Tokens.rowFill
        border.width: 1
        border.color: on ? sheet.accent : Tokens.rowBorder

        Behavior on color {
            ColorAnimation { duration: 90 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 90 }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Tokens.headerIcon
            height: Tokens.headerIcon
            source: button.source
            color: Tokens.text
            isMask: true
            active: false
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Kicker.RootModel {
        id: rootModel

        autoPopulate: true
            appletInterface: sheet.applet

        showSeparators: false
        showTopLevelItems: false
        showAllApps: false
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showFavoritesPlaceholder: false

        // Kickoff's client id on purpose: favourites live in kactivitymanagerd
        // under whichever id asks for them, so borrowing Kickoff's means
        // anything already pinned there is already here.
        Component.onCompleted: favoritesModel.initForClient("org.kde.plasma.kickoff")
    }

    ListModel {
        id: recentFiles
    }

    ListModel {
        id: sessions
    }

    // What each column shows, assembled by rebuildColumns().
    ListModel {
        id: appRows
    }

    ListModel {
        id: fileRows
    }

    ListModel {
        id: taskRows
    }

    // Applications lately used, which is Plasma's own record of it.
    Kicker.RecentUsageModel {
        id: recentApps

        shownItems: Kicker.RecentUsageModel.OnlyApps
        ordering: Kicker.RecentUsageModel.Recent
        favoritesModel: rootModel.favoritesModel
    }

    // Kicker's models are read the same way KRunner's is: by asking an
    // Instantiator's delegates for their roles rather than the model for
    // role numbers.
    Instantiator {
        id: keptApps

        model: rootModel.favoritesModel

        delegate: QtObject {
            required property var model

            readonly property string display: model.display ?? ""
            readonly property var decoration: model.decoration ?? ""
            readonly property string favoriteId: model.favoriteId ?? ""
        }

        onObjectAdded: columns.restart()
        onObjectRemoved: columns.restart()
    }

    Instantiator {
        id: usedApps

        model: recentApps

        delegate: QtObject {
            required property var model

            readonly property string display: model.display ?? ""
            readonly property var decoration: model.decoration ?? ""
            readonly property string favoriteId: model.favoriteId ?? ""
        }

        onObjectAdded: columns.restart()
        onObjectRemoved: columns.restart()
    }

    Timer {
        id: columns

        interval: 0
        onTriggered: sheet.rebuildColumns()
    }

    // What a search found: matching tasks, then KRunner's own answers.
    ListModel {
        id: found
    }

    // KRunner's results live in a model of its own and QML has no proxy
    // for concatenating two models, so its rows are read out one by one.
    // An Instantiator resolves the role names exactly as a delegate would,
    // which is what makes this safe: the alternative is passing role
    // numbers to data(), and those are Kicker's private business.
    Instantiator {
        id: harvest

        model: sheet.results

        delegate: QtObject {
            required property var model

            readonly property string display: model.display ?? ""
            readonly property var decoration: model.decoration ?? ""
            readonly property string description: model.description ?? ""

            // What it would take to keep this row: an application says
            // which favourite it is, a file or a folder says where it is.
            // Both roles are Kicker's own and neither is promised for
            // every runner, so a missing one is an answer, not an error.
            readonly property string favoriteId: {
                try {
                    return model.favoriteId ?? "";
                } catch (e) {
                    return "";
                }
            }

            readonly property string url: {
                try {
                    return model.url ?? "";
                } catch (e) {
                    return "";
                }
            }
        }

        // Results stream in a few at a time; rebuilding once the batch has
        // settled keeps one keystroke to one rebuild.
        onObjectAdded: settle.restart()
        onObjectRemoved: settle.restart()
    }

    Timer {
        id: settle

        interval: 0
        onTriggered: sheet.rebuildResults()
    }

    KCoreAddons.KUser {
        id: user
    }

    // The same object Kickoff's power buttons drive, so "can this machine
    // suspend?" is answered by logind rather than assumed.
    PlasmaSessions.SessionManagement {
        id: session
    }

    // Search is KRunner's, so one field finds applications, system settings,
    // places, bookmarks, recent documents and — through baloosearch — files and
    // folders by name and by content, the way Kickoff's does.
    Kicker.RunnerModel {
        id: runnerModel

            appletInterface: sheet.applet
        favoritesModel: rootModel.favoritesModel
        mergeResults: true

        // Named rather than left open: a launcher that will run an arbitrary
        // shell line on Enter is a different and more dangerous thing, and
        // Enter here already means something else.
        runners: ["krunner_services", "baloosearch", "krunner_placesrunner",
                  "krunner_systemsettings", "krunner_recentdocuments",
                  "krunner_bookmarksrunner", "calculator", "unitconverter",
                  "locations"]

        query: sheet.query
    }

    // The executable engine is how a Plasma applet starts a process. It keeps
    // a source connected until it is told not to, so every launch disconnects
    // itself as soon as the command has run.
    Plasma5Support.DataSource {
        id: reader

        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            reader.disconnectSource(source);
            const text = data["stdout"] ?? "";
            if (source.indexOf("sessions.py") >= 0) {
                sheet.loadSessions(text);
            } else {
                sheet.loadRecent(text);
            }
        }
    }

    Plasma5Support.DataSource {
        id: runner

        engine: "executable"
        connectedSources: []

        onNewData: source => runner.disconnectSource(source)

        function exec(command: string): void {
            runner.connectSource(command);
        }
    }


    // --- who this is, and the two ways out --------------------------

    Item {
        id: header

        x: Tokens.sheetPadX
        y: Tokens.sheetPadY
        width: parent.width - Tokens.sheetPadX * 2
        height: Tokens.headerHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            text: i18n("Welcome, %1", sheet.firstName)
            color: Tokens.text
            font.pointSize: Tokens.pt(16)
            font.weight: Font.Medium
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            IconButton {
                // The gear, the same one the quick-settings sheet
                // uses for its way into System Settings; Breeze's
                // "configure" is a set of sliders.
                source: "applications-system-symbolic"
                onClicked: sheet.openSettings()
            }

            IconButton {
                source: "system-shutdown-symbolic"
                on: powerMenu.visible
                onClicked: powerMenu.visible = !powerMenu.visible
            }
        }
    }

    // --- the field ------------------------------------------------

    Rectangle {
        id: searchBox

        x: Tokens.sheetPadX
        y: Tokens.sheetPadY + Tokens.headerHeight + Tokens.headerGap
        width: parent.width - Tokens.sheetPadX * 2
        height: Tokens.searchHeight

        radius: Tokens.searchRadius
        color: Tokens.rowFill
        border.width: 1
        border.color: search.activeFocus ? sheet.accent : Tokens.rowBorder

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        Kirigami.Icon {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.rowPadX
            anchors.verticalCenter: parent.verticalCenter
            width: Tokens.rowIcon
            height: Tokens.rowIcon
            source: "search-symbolic"
            color: Tokens.detail
            isMask: true
            active: false
        }

        PC3.TextField {
            id: search

            anchors.left: searchIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: Tokens.rowPadX
            anchors.verticalCenter: parent.verticalCenter

            background: null
            placeholderText: i18n("Search, or ask Claude")
            font.pointSize: Tokens.pt(12.5)
            color: Tokens.text

            // The field keeps focus the whole time the sheet is open —
            // typing is never lost to a list — and the arrows walk the
            // suggestions from here.
            Keys.onDownPressed: sheet.step(1)
            Keys.onUpPressed: sheet.step(-1)
            Keys.onReturnPressed: sheet.accept()
            Keys.onEnterPressed: sheet.accept()

            Keys.onEscapePressed: {
                if (powerMenu.visible) {
                    powerMenu.visible = false;
                } else if (text !== "") {
                    text = "";
                } else {
                    sheet.visible = false;
                }
            }
        }
    }

    // --- suggestions, while there is something to suggest ---------

    // One list for everything a query found — an application, a file
    // and an AI task read the same and sit together.

    MenuColumn {
        visible: sheet.searching

        x: Tokens.sheetPadX
        y: searchBox.y + searchBox.height + Tokens.sectionGap
        width: parent.width - Tokens.sheetPadX * 2

        title: i18n("Suggestions")
        source: found
        rows: sheet.visibleRows
        showDetail: true
        accent: sheet.accent
        pinnable: true
        selected: sheet.selected
        emptyText: i18n("Nothing matches — press Enter to ask Claude instead")

        onTriggered: index => sheet.take(index)
        onHovered: index => sheet.selected = index
        onPinToggled: index => sheet.toggleFound(index)
    }

    // --- or the three resting columns -----------------------------

    Row {
        visible: !sheet.searching

        x: Tokens.sheetPadX
        y: searchBox.y + searchBox.height + Tokens.sectionGap
        width: parent.width - Tokens.sheetPadX * 2
        spacing: Tokens.columnGap

        readonly property int columnWidth: (width - Tokens.columnGap * 2) / 3

        MenuColumn {
            width: parent.columnWidth
            title: i18n("Apps")
            source: appRows
            rows: sheet.visibleRows
            accent: sheet.accent
            pinnable: true
            reorderable: true
            emptyText: i18n("Nothing here yet")

            onTriggered: index => sheet.openApp(index)
            onPinToggled: index => sheet.toggleApp(index)
            onMoved: (from, to) => appRows.move(from, to, 1)
            onDropped: sheet.commitApps()
        }

        MenuColumn {
            width: parent.columnWidth
            title: i18n("Files")
            source: fileRows
            rows: sheet.visibleRows
            accent: sheet.accent
            pinnable: true
            reorderable: true
            emptyText: i18n("Nothing opened lately")

            onTriggered: index => sheet.openPath(index)
            onPinToggled: index => sheet.toggleFile(index)
            onMoved: (from, to) => fileRows.move(from, to, 1)
            onDropped: sheet.commitFiles()
        }

        MenuColumn {
            width: parent.columnWidth
            title: i18n("AI tasks")
            source: taskRows
            rows: sheet.visibleRows
            accent: sheet.accent
            pinnable: true
            reorderable: true
            emptyText: i18n("No tasks yet")

            onTriggered: index => sheet.resumeTask(index)
            onPinToggled: index => sheet.toggleTask(index)
            onMoved: (from, to) => taskRows.move(from, to, 1)
            onDropped: sheet.commitTasks()
        }
    }

    // --- the way out at the bottom --------------------------------
    //
    // The design's own Ask row: a dot that breathes, the line itself,
    // and what Enter will do with it. It stands in for "nothing in the
    // list is picked", so it lights up exactly when Enter would take
    // this rather than a suggestion.

    Rectangle {
        id: askRow

        // Always there, in both states: the sheet is one fixed height,
        // and a row that came and went would leave a bare strip under
        // the columns when it was away. With nothing typed it is the
        // sheet's invitation rather than a live command.
        readonly property bool armed: sheet.searching && sheet.selected < 0

        x: Tokens.sheetPadX
        y: sheet.sheetHeight - Tokens.sheetPadY - Tokens.askHeight
        width: parent.width - Tokens.sheetPadX * 2
        height: Tokens.askHeight

        radius: Tokens.rowRadius
        color: askMouse.containsMouse || armed
            ? Tokens.rowHover : Tokens.rowFill
        border.width: 1
        border.color: armed ? sheet.accent : Tokens.rowBorder

        Behavior on color {
            ColorAnimation { duration: 90 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 90 }
        }

        Rectangle {
            id: pulse

            anchors.left: parent.left
            anchors.leftMargin: Tokens.rowPadX
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: width / 2
            color: sheet.accent

            // The design breathes this dot on a five-second cycle. It
            // runs only while the sheet is up, so nothing is animating
            // on an idle desktop.
            SequentialAnimation on opacity {
                running: sheet.visible && sheet.searching
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.35; duration: 2500; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1; duration: 2500; easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            anchors.left: pulse.right
            anchors.leftMargin: 12
            anchors.right: hint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            text: sheet.searching
                ? i18n("Ask Claude: %1", sheet.query)
                : i18n("Ask Claude")
            color: sheet.searching ? Tokens.text : Tokens.textDim
            font.pointSize: Tokens.pt(12.5)
            elide: Text.ElideRight
        }

        Text {
            id: hint

            anchors.right: parent.right
            anchors.rightMargin: Tokens.rowPadX
            anchors.verticalCenter: parent.verticalCenter

            text: sheet.searching
                ? i18n("⏎ in a new terminal")
                : i18n("type a question")
            color: Tokens.detail
            font.pointSize: Tokens.pt(10.5)
        }

        MouseArea {
            id: askMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sheet.ask()
            onEntered: sheet.selected = -1
        }
    }

    // --- what the power button opens -------------------------------
    //
    // Inside the sheet rather than in a window of its own: a second
    // dialog would take the focus, and a sheet that hides when it
    // loses focus would close underneath its own menu. Last in the
    // file so it paints over the columns, with a catcher behind it so
    // the next click anywhere else puts it away.

    MouseArea {
        anchors.fill: parent
        visible: powerMenu.visible
        onClicked: powerMenu.visible = false
    }

    Rectangle {
        id: powerMenu

        visible: false

        width: Tokens.powerMenuWidth
        x: parent.width - Tokens.sheetPadX - width
        y: header.y + header.height + Tokens.powerMenuPad
        height: powerColumn.height + Tokens.powerMenuPad * 2

        radius: Tokens.rowRadius + Tokens.powerMenuPad / 2
        color: Tokens.menu
        border.width: 1
        border.color: Tokens.sheetBorder

        Column {
            id: powerColumn

            x: Tokens.powerMenuPad
            y: Tokens.powerMenuPad
            width: parent.width - Tokens.powerMenuPad * 2
            spacing: Tokens.rowGap

            MenuRow {
                width: parent.width
                visible: session.canLock
                accent: sheet.accent
                label: i18n("Lock")
                iconSource: "system-lock-screen-symbolic"

                onActivated: {
                    sheet.visible = false;
                    session.lock();
                }
            }

            MenuRow {
                width: parent.width
                visible: session.canSuspend
                accent: sheet.accent
                label: i18n("Standby")
                iconSource: "system-suspend-symbolic"

                onActivated: {
                    sheet.visible = false;
                    session.suspend();
                }
            }

            MenuRow {
                width: parent.width
                visible: session.canReboot
                accent: sheet.accent
                label: i18n("Restart")
                iconSource: "system-reboot-symbolic"

                onActivated: {
                    sheet.visible = false;
                    session.requestReboot();
                }
            }

            MenuRow {
                width: parent.width
                visible: session.canShutdown
                accent: sheet.accent
                label: i18n("Shut down")
                iconSource: "system-shutdown-symbolic"

                onActivated: {
                    sheet.visible = false;
                    session.requestShutdown();
                }
            }
        }
    }
}
