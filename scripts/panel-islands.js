// The design's two bottom islands:
//   centre — launcher, task switcher, and the tray that backs the quick tiles
//   right  — the time pill, nothing else (design/naiture-canvas.dc.html shows
//            the resting pill containing only "10:12")
//
// Only creation, applet population and location happen here. plasmashell keeps
// panel *geometry* in plasmashellrc, and only picks up changes there on start,
// so install.sh follows this with scripts/panel-style.sh.
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

island([
  "org.kde.plasma.kickoff",
  "org.naiture.dock"
]);

// The design's time pill opens a panel of quick tiles — Wi-Fi, Bluetooth,
// Sound, Do not disturb — over volume and brightness sliders. That is what
// Plasma's system tray popup already is, so the tray sits in the time island
// with every icon hidden; scripts/panel-style.sh does the hiding, leaving just
// the expander next to the clock.
var time = island([
  "org.kde.plasma.systemtray",
  "org.kde.plasma.digitalclock"
]);

// The clock is the design's pill: just the time, 24-hour, no date.
try {
  var clock = time.widgetIds.length ? widgetById(time.widgetIds[0]) : null;
  if (clock) {
    clock.currentConfigGroup = ["Appearance"];
    clock.writeConfig("showDate", false);
    clock.writeConfig("use24hFormat", 2);
    clock.writeConfig("showSeconds", 0);
    clock.reloadConfig();
  }
} catch (e) {}

"islands built";
