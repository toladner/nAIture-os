.pragma library

// Recently used files, from ~/.local/share/recently-used.xbel — the XDG list
// that both toolkits write, and the one with anything in it on a machine whose
// owner mostly works in a terminal. Kicker's RecentUsageModel reads
// kactivitymanagerd's resource scores instead, which stay empty until KDE
// applications have been opening documents for a while.
//
// The file is bookmarks, not only files: browsers record visited URLs in it
// too, so only file:// entries are of any use here.

// The freedesktop icon for a mime type is the type with its slash swapped for
// a dash, which is why no mime lookup is needed to draw the right icon.
function mimeIcon(type) {
    if (!type) {
        return "text-x-generic";
    }
    return type.replace("/", "-");
}

function basename(path) {
    const parts = path.split("/").filter(p => p !== "");
    return parts.length ? parts[parts.length - 1] : path;
}

function dirname(path) {
    const cut = path.lastIndexOf("/");
    return cut > 0 ? path.slice(0, cut) : "/";
}

function parseXbel(text, home, limit) {
    const out = [];

    // Split on the closing tag so each chunk holds exactly one bookmark and a
    // greedy match cannot reach into the next one.
    for (const chunk of text.split("</bookmark>")) {
        const href = /href="(file:\/\/[^"]+)"/.exec(chunk);
        if (!href) {
            continue;
        }
        let path;
        try {
            path = decodeURIComponent(href[1].slice("file://".length));
        } catch (e) {
            continue;
        }
        const modified = /modified="([^"]*)"/.exec(chunk);
        const mime = /<mime:mime-type type="([^"]*)"/.exec(chunk);
        out.push({
            path: path,
            name: basename(path),
            // Where it is matters more than that it is in $HOME.
            where: dirname(path).replace(home, "~"),
            icon: mimeIcon(mime ? mime[1] : ""),
            when: modified ? modified[1] : ""
        });
    }

    // The timestamps are ISO 8601 in UTC, so they sort as strings.
    return out.sort((a, b) => (a.when < b.when ? 1 : a.when > b.when ? -1 : 0))
              .slice(0, limit);
}
