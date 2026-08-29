// The design's two bottom islands:
//   centre — the mark, the rule and the switcher, in one applet
//   right  — the time pill and the show-desktop sliver (design/naiture-canvas.dc.html
//            shows the resting pill containing only "10:12")
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

// The dock carries the mark, the rule and the running apps in one applet,
// because the accent bar is one rectangle that slides between them and two
// applets are two coordinate spaces with a panel layout in between.
island([
  "org.naiture.dock"
]);

// The design's time pill opens a panel of quick tiles over volume and
// brightness sliders. Plasma's tray plus its clock is the nearest stock pair,
// but the tray always shows an expander chevron beside the time and its popup
// is Plasma's list rather than the design's sheet, so both are ours. The
// sliver at the corner is a separate applet because Plasma draws its "this
// applet is open" bar across a whole applet, and folding the sliver into the
// clock would stretch that bar past the time.
island([
  "org.naiture.quicksettings",
  "org.naiture.showdesktop"
]);

"islands built";
