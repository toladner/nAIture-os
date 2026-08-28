// The design's two bottom islands: a centred switcher (launcher + tasks) and a
// right-hand time island (tray + clock).
//
// Only creation, applet population and location are done here — plasmashell 6.6
// does not persist Panel geometry set from a script, so install.sh follows this
// with scripts/panel-style.sh, which writes thickness/floating/alignment to the
// containment config and restarts the shell.
for (var i = panelIds.length - 1; i >= 0; i--) {
  var old = panelById(panelIds[i]);
  if (old) { try { old.remove(); } catch (e) {} }
}

function island(applets) {
  var p = new Panel("org.kde.panel");
  p.location = "bottom";
  for (var i = 0; i < applets.length; i++) {
    try { p.addWidget(applets[i]); } catch (e) {}
  }
  return p;
}

var switcher = island([
  "org.kde.plasma.kickoff",
  "org.kde.plasma.icontasks"
]);

var time = island([
  "org.kde.plasma.systemtray",
  "org.kde.plasma.digitalclock"
]);

// install.sh reads these ids back to align the time island to the right edge.
"switcher=" + switcher.id + " time=" + time.id;
