.pragma library

// Launching, and the little that is left of reading. Finding the sessions is
// contents/code/sessions.py's job: the titles live at the end of transcripts
// that run to tens of megabytes, so that is a seek, not something to hand to
// QML through a pipe.

// The last path component, which is what a project is called day to day.
function projectName(path) {
    const parts = (path || "").split("/").filter(p => p !== "");
    return parts.length ? parts[parts.length - 1] : path;
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// Konsole's -e takes the program and its arguments, but the executable data
// engine hands the whole line to a shell, so everything still has to be quoted.
//
// --desktopfile is what makes this window its own application: on Wayland the
// icon comes from the desktop file the process declares, and without it every
// Claude session is another Konsole in the dock. scripts/claude-console.sh
// installs the entry it names.
//
// systemd-run is what keeps the session alive. The executable engine starts a
// shell as a child of plasmashell, so anything it launches is plasmashell's
// too — in its process group and inside its systemd unit — and a plasmashell
// that restarts takes the whole cgroup down with it. Handing the line to
// systemd instead starts it beside plasmashell rather than under it: a
// transient unit of its own, which outlives the shell that asked for it. It is
// also what Plasma's own launcher does with every application it starts.
function detached(cmd) {
    return "systemd-run --user --quiet --collect -- " + cmd;
}

// naiture-view is what gives the session its view out of the window; it sets
// the session's own profile and then exec's what follows. It has to be named
// here because -e replaces the profile's Command outright, and scripts/
// console.sh puts a copy of it on PATH for exactly this line.
function terminal(workdir, args, profile) {
    let cmd = "konsole --desktopfile naiture-claude --profile " + shellQuote(profile)
        + " --workdir " + shellQuote(workdir) + " -e naiture-view";
    for (const a of args) {
        cmd += " " + shellQuote(a);
    }
    return detached(cmd);
}

function resumeCommand(entry, profile) {
    return terminal(entry.project, ["claude", "--resume", entry.sessionId], profile);
}

// An asked question is a throwaway: it runs in a directory of its own so that
// nothing it writes to the history can turn up in the recent list, which is
// also why parseHistory takes that directory as its exclusion.
function askCommand(question, askDir, profile) {
    return "mkdir -p " + shellQuote(askDir) + " && "
        + terminal(askDir, ["claude", question], profile);
}
