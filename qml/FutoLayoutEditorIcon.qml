import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: root
    objectName: "layoutEditorCompositeIcon"
    property bool highlighted: false
    implicitWidth: Theme.iconSizeMedium
    implicitHeight: implicitWidth

    Icon {
        objectName: "layoutEditorKeyboardGlyph"
        width: root.width * 0.96; height: root.height * 0.96
        x: root.width * 0.02; y: root.height * 0.10
        source: "image://theme/icon-m-keyboard"
        highlighted: root.highlighted
        layer.enabled: true
        layer.effect: ShaderEffect {
            fragmentShader: "varying highp vec2 qt_TexCoord0; uniform sampler2D source; uniform lowp float qt_Opacity; void main() { highp vec2 canvas = qt_TexCoord0 * 0.96 + vec2(0.02, 0.10); highp vec2 p = (canvas - vec2(0.40, 0.15)) / 0.54; highp vec2 a = vec2(0.18, 0.82); highp vec2 b = vec2(0.82, 0.18); highp vec2 ab = b - a; highp float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0); highp float d = length(p - a - t * ab); lowp float visible = smoothstep(0.108, 0.134, d); gl_FragColor = texture2D(source, qt_TexCoord0) * visible * qt_Opacity; }"
        }
    }
    Icon {
        objectName: "layoutEditorPencilGlyph"
        width: root.width * 0.54; height: root.height * 0.54
        x: root.width * 0.40; y: root.height * 0.15
        source: "image://theme/icon-m-edit"
        highlighted: root.highlighted
    }
}
