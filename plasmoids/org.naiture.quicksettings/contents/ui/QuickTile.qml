/*
 * One tile of the quick-settings grid: a glyph badge, a name and a detail line,
 * tinted sky when the thing it controls is on.
 *
 * design/naiture-canvas.logic.js, quickTiles:
 *   tile   padding 11px 13px, radius 13
 *          on  — background sky/0.2, border sky/0.45
 *          off — background white/0.05, border white/0.09
 *   glyph  30x30, radius 9, 14px
 *          on  — background skyBright/0.3, colour skyPale
 *          off — background white/0.07, colour text/0.5
 *   name   12.5px           detail 10.5px, text/0.45
 *   hover  background white/0.14
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Rectangle {
    id: tile

    // The design draws these as typographic glyphs. A tile can take a real
    // icon instead where one says the thing better than a glyph can.
    required property string glyph
    property string iconName: ""
    required property string name
    required property string detail
    required property bool on
    // Set false for a control the machine does not have; the tile then reads as
    // off and does not react, rather than pretending to work.
    property bool available: true

    // The one accent. main.qml feeds this from the colour scheme so a tile is
    // never the source of a colour; Tokens.sky is only the fallback for a tile
    // used outside the applet.
    property color accent: Tokens.sky

    signal toggled()

    implicitHeight: row.implicitHeight + Tokens.tilePadY * 2
    radius: Tokens.tileRadius

    color: !available ? Qt.rgba(1, 1, 1, 0.03)
         : hover.hovered ? Qt.rgba(1, 1, 1, 0.14)
         : on ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.2)
         : Qt.rgba(1, 1, 1, 0.05)

    border.width: 1
    border.color: on && available
        ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.45)
        : Qt.rgba(1, 1, 1, 0.09)

    Behavior on color {
        ColorAnimation { duration: 180 }
    }

    HoverHandler {
        id: hover
        enabled: tile.available
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: tile.available
        onTapped: tile.toggled()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Tokens.tilePadX
        anchors.rightMargin: Tokens.tilePadX
        anchors.topMargin: Tokens.tilePadY
        anchors.bottomMargin: Tokens.tilePadY
        spacing: 11

        Rectangle {
            Layout.preferredWidth: Tokens.glyphSize
            Layout.preferredHeight: Tokens.glyphSize
            radius: Tokens.glyphRadius
            readonly property color badge: Qt.lighter(tile.accent, 1.15)

            color: tile.on && tile.available
                ? Qt.rgba(badge.r, badge.g, badge.b, 0.3)
                : Qt.rgba(1, 1, 1, 0.07)

            Behavior on color {
                ColorAnimation { duration: 180 }
            }

            readonly property color mark: tile.on && tile.available
                ? Qt.lighter(tile.accent, 1.45)
                : Qt.rgba(Tokens.text.r, Tokens.text.g, Tokens.text.b, 0.5)

            PC3.Label {
                anchors.centerIn: parent
                visible: tile.iconName === ""
                text: tile.glyph
                font.pointSize: Tokens.pt(14)
                color: parent.mark
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                visible: tile.iconName !== ""
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                source: tile.iconName
                color: parent.mark
                isMask: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            PC3.Label {
                Layout.fillWidth: true
                text: tile.name
                elide: Text.ElideRight
                font.pointSize: Tokens.pt(12.5)
                color: tile.on && tile.available
                    ? Qt.rgba(Tokens.text.r, Tokens.text.g, Tokens.text.b, 0.95)
                    : Qt.rgba(Tokens.text.r, Tokens.text.g, Tokens.text.b, 0.7)
            }

            PC3.Label {
                Layout.fillWidth: true
                text: tile.detail
                elide: Text.ElideRight
                font.pointSize: Tokens.pt(10.5)
                color: Tokens.detail
            }
        }
    }
}
