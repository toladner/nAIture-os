/*
 * The window both sheets open in. Only what is inside them differs.
 *
 * A plasmoid package cannot import another package's QML, so this file is
 * duplicated in plasmoids/org.naiture.quicksettings/contents/ui/Sheet.qml. The
 * two are the same window and have to stay in step.
 *
 * The sheet paints itself, in a window that paints nothing. On 6.7 an applet
 * popup draws an opaque background of its own that neither the theme nor
 * `backgroundHints` reaches, and a PlasmaCore.Dialog is what does honour
 * `NoBackground` — so the design's rounded, translucent panel is a Rectangle
 * drawn inside a window with nothing in it, and `Plasmoid.expanded` is never
 * used.
 *
 * That costs the blur: PlasmaQuick::Dialog only asks KWindowEffects to blur
 * what is behind a window when it has a *Plasma* background whose shape it can
 * hand over (plasmaquick/dialog.cpp, DialogPrivate::updateTheme). Letting
 * Plasma paint the sheet instead buys the blur and loses the sheet — its own
 * frame, its own margins, its own shadow, none of them the design's.
 *
 * Two more things, both learned the hard way:
 *
 *   - **The dialog takes the size it is first given** and does not grow later.
 *     `sheetWidth`/`sheetHeight` are set from constants by whoever fills the
 *     sheet; nothing here waits on a child to report a size, or the window
 *     keeps whatever the first, unresolved binding said.
 *   - **The window is bigger than the sheet.** Under it runs a strip of
 *     nothing, which is what holds the sheet clear of the island rather than
 *     resting it on top; beside it, when the sheet keeps to the screen's edge,
 *     runs another, which lets the window reach the edge while the sheet keeps
 *     a hair of daylight.
 *
 * Plasma then places the window itself, and only roughly: it centres a popup
 * on its applet until the screen gets in the way. That is corrected once
 * Plasma has finished — which is what the Qt.callLater is for.
 */
import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.Dialog {
    id: sheet

    // The sheet's own size. Constants, never a child's implicit size.
    property int sheetWidth: 0
    property int sheetHeight: 0

    // What to centre on — the tile that opened it — or nothing, in which case
    // the sheet keeps to the screen's trailing edge, a hair inside it.
    property Item anchorItem: null

    // Everything declared inside a Sheet {} lands in the sheet itself: (0, 0)
    // is its top-left corner, and its width and height are sheetWidth and
    // sheetHeight.
    default property alias body: panel.data

    signal opened()
    signal closed()

    type: PlasmaCore.Dialog.AppletPopup
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: true

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(place);
            opened();
        } else {
            closed();
        }
    }

    function place(): void {
        const output = sheet.screen;
        if (!output) {
            return;
        }

        let x;
        if (anchorItem) {
            const centre = anchorItem.mapToGlobal(anchorItem.width / 2, 0);
            x = centre.x - sheet.width / 2;
        } else {
            x = output.virtualX + output.width - sheet.width;
        }

        const leftmost = output.virtualX;
        const rightmost = output.virtualX + output.width - sheet.width;
        sheet.x = Math.round(Math.max(leftmost, Math.min(rightmost, x)));
    }

    mainItem: Item {
        implicitWidth: sheet.sheetWidth
            + (sheet.anchorItem ? 0 : Tokens.sheetEdgeGap)
        implicitHeight: sheet.sheetHeight + Tokens.sheetLift

        Rectangle {
            id: panel

            anchors.top: parent.top
            anchors.left: parent.left
            width: sheet.sheetWidth
            height: sheet.sheetHeight

            radius: Tokens.sheetRadius
            color: Tokens.sheet
            border.width: 1
            border.color: Tokens.sheetBorder
        }
    }
}
