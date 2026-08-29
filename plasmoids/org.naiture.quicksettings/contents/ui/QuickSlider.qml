/*
 * A labelled slider drawn the way the design draws it — a 4px rule, a tinted
 * fill and the percentage in mono on the right — rather than as a themed
 * PC3.Slider, which brings its own handle and groove.
 *
 * design/naiture-canvas.logic.js, sliders:
 *   name   11.5px, text/0.6, 68px wide
 *   track  4px tall, fully rounded, white/0.11
 *   value  10px mono, text/0.4, 30px wide, right aligned
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3

RowLayout {
    id: slider

    required property string name
    required property color tint
    // 0..1
    required property real value
    property bool available: true

    signal moved(real value)

    spacing: 12
    opacity: available ? 1 : 0.4

    function setFromX(x) {
        if (!available || track.width <= 0) {
            return;
        }
        slider.moved(Math.max(0, Math.min(1, x / track.width)));
    }

    PC3.Label {
        Layout.preferredWidth: Tokens.sliderLabelWidth
        text: slider.name
        font.pointSize: Tokens.pt(11.5)
        color: Qt.rgba(Tokens.text.r, Tokens.text.g, Tokens.text.b, 0.6)
    }

    Item {
        Layout.fillWidth: true
        // The rule is 4px, but the pointer needs something bigger to grab.
        implicitHeight: 16

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Tokens.trackHeight
            radius: height / 2
            color: Tokens.track

            Rectangle {
                width: Math.max(parent.radius * 2, parent.width * slider.value)
                height: parent.height
                radius: parent.radius
                color: slider.tint

                Behavior on width {
                    NumberAnimation { duration: 120 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: slider.available
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => slider.setFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) {
                    slider.setFromX(mouse.x);
                }
            }
        }
    }

    PC3.Label {
        Layout.preferredWidth: Tokens.sliderValueWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(slider.value * 100) + "%"
        font.pointSize: Tokens.pt(10)
        font.features: ({ "tnum": 1 })
        color: Qt.rgba(Tokens.detail.r, Tokens.detail.g, Tokens.detail.b, 0.4)
    }
}
