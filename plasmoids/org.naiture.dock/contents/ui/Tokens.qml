/*
 * The design's tokens for the start sheet. A plasmoid package cannot import
 * another package's QML, so this is a trimmed copy of
 * plasmoids/org.naiture.quicksettings/contents/ui/Tokens.qml — the two sheets
 * are the same object in the design and have to stay in step.
 *
 * The dock's own geometry is not here: that is worked out from the panel
 * background's margins in main.qml, and belongs beside the code that uses it.
 */
pragma Singleton
import QtQuick

QtObject {
    readonly property color text: "#f2f7f2"
    readonly property color textDim: Qt.rgba(0.949, 0.969, 0.949, 0.55)
    readonly property color detail: Qt.rgba(0.922, 0.957, 0.925, 0.45)

    // The sheet, identical to the quick-settings one but for its width: the
    // design gives the start menu 660px and three columns.
    // The design's 0.85 goes with a 40px backdrop blur, and there is no
    // blur to be had: KWin only blurs behind a window whose background
    // Plasma itself paints, and letting it paint this one costs the sheet
    // its shape, its margins and its shadow. So the panel makes up the
    // difference by being that much less see-through.
    readonly property color sheet: Qt.rgba(13 / 255, 24 / 255, 17 / 255, 0.94)
    readonly property color sheetBorder: Qt.rgba(1, 1, 1, 0.16)
    readonly property int sheetWidth: 660
    readonly property int sheetRadius: 20
    readonly property int sheetPadY: 22
    readonly property int sheetPadX: 24
    readonly property int sectionGap: 18
    readonly property int columnGap: 24

    // Daylight between the sheet and the island, and the overlap Plasma parks
    // the dialog's window at, which the lift has to cover first.
    readonly property int sheetEdgeGapVertical: 4
    readonly property int islandOverlap: 7
    readonly property int sheetLift: sheetEdgeGapVertical + islandOverlap

    // The panel background's margin, from tools/make_panel_svg.py: how far
    // inside the island's edge an applet is laid out, and so how far a marker
    // that belongs to that edge has to reach back out. Keep the two in step.
    readonly property int islandMargin: 7
    readonly property int markerThickness: 3

    // A row in a column: the design's 9px/12px padding on a 10px radius.
    readonly property int rowHeight: 34
    readonly property int rowGap: 6
    readonly property int rowRadius: 10
    readonly property int rowPadX: 12
    readonly property int rowIcon: 18
    readonly property color rowFill: Qt.rgba(1, 1, 1, 0.05)
    readonly property color rowBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.12)

    // How many rows a column shows before it scrolls.
    readonly property int maxRows: 7
    readonly property int minRows: 3

    readonly property int headingHeight: 14
    readonly property int headingGap: 10

    readonly property int searchHeight: 38
    readonly property int searchRadius: 12

    // The header above the field: the greeting on one side, the cog and the
    // power button on the other.
    readonly property int headerHeight: 30
    readonly property int headerGap: 16
    readonly property int headerButton: 30
    readonly property int headerIcon: 17

    // The power button's little menu, drawn inside the sheet rather than in a
    // window of its own — a second PlasmaCore.Dialog would take the focus off
    // the field and close the sheet under it.
    readonly property color menu: Qt.rgba(21 / 255, 36 / 255, 26 / 255, 0.98)
    readonly property int powerMenuWidth: 200
    readonly property int powerMenuPad: 8

    // The ask row under the suggestions.
    readonly property int askHeight: 40
    readonly property int askGap: 14

    // The design's type sizes are fractional pixels and font.pixelSize is an
    // int, so everything goes through points: Qt turns those into logical
    // pixels at 96 logical DPI, which is what a Plasma logical pixel is.
    function pt(px) {
        return px * 72 / 96;
    }
}
