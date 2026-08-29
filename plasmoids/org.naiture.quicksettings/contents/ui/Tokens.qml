/*
 * The design's tokens for the time pill and its quick-settings sheet, taken
 * from palette/naiture.json and design/naiture-canvas.logic.js. The OKLCH
 * values in the design convert to these sRGB ones via tools/oklch.py:
 *
 *   oklch(0.76 0.09 220)  #6abfd9  sky        tile when on
 *   oklch(0.80 0.09 220)  #77cce6  skyBright  glyph badge when on
 *   oklch(0.95 0.05 220)  #caf7ff  skyPale    glyph itself when on
 *   oklch(0.84 0.13 100)  #decc60  gold       the brightness slider
 */
pragma Singleton
import QtQuick

QtObject {
    readonly property color sky: "#6abfd9"
    readonly property color skyBright: "#77cce6"
    readonly property color skyPale: "#caf7ff"
    readonly property color gold: "#decc60"

    readonly property color text: "#f2f7f2"
    readonly property color textDim: Qt.rgba(0.949, 0.969, 0.949, 0.55)
    readonly property color detail: Qt.rgba(0.922, 0.957, 0.925, 0.45)

    // The sheet itself
    readonly property color sheet: Qt.rgba(13 / 255, 24 / 255, 17 / 255, 0.85)
    readonly property color sheetBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property int sheetWidth: 400
    readonly property int sheetRadius: 20
    readonly property int sheetPadY: 20
    readonly property int sheetPadX: 22
    readonly property int sectionGap: 18

    // How close the sheet's right edge comes to the screen's, and — matching it
    // — how far its bottom edge floats above the island.
    readonly property int sheetEdgeGapVertical: 4

    // Plasma parks the dialog's window this far over the panel, so the lift has
    // to cover that before any of it becomes daylight.
    readonly property int islandOverlap: 7

    readonly property int sheetLift: sheetEdgeGapVertical + islandOverlap
    readonly property int sheetEdgeGap: 4

    // The panel background's top margin, from tools/make_panel_svg.py. An
    // applet is laid out inside it, so a marker that belongs to the island's
    // edge has to reach back out by exactly this much. Keep the two in step.
    readonly property int islandTopMargin: 7

    // Tiles
    readonly property int tileGap: 9
    readonly property int tileRadius: 13
    readonly property int tilePadX: 13
    readonly property int tilePadY: 11
    readonly property int glyphSize: 30
    readonly property int glyphRadius: 9

    // Sliders
    readonly property int sliderGap: 13
    readonly property int trackHeight: 4
    readonly property int sliderLabelWidth: 68
    readonly property int sliderValueWidth: 30
    readonly property color track: Qt.rgba(1, 1, 1, 0.11)

    // The Konsole profile's size, so the pill's clock matches the terminal it
    // sits under rather than the design's smaller 13px.
    readonly property real terminalPointSize: 11

    // The design's type sizes are fractional pixels (12.5, 11.5, 10.5), and
    // font.pixelSize is an int. font.pointSize is a real, and Qt turns points
    // into logical pixels at 96 logical DPI — which is what a Plasma logical
    // pixel is — so the fractions survive, and they scale with the display.
    function pt(px) {
        return px * 72 / 96;
    }
}
