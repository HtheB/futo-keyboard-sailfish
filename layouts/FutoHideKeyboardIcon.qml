import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: glyph
    property color color: Theme.primaryColor
    implicitWidth: Theme.iconSizeMedium
    implicitHeight: implicitWidth
    Icon {
        anchors.fill: parent
        source: "image://theme/icon-m-keyboard"
        color: glyph.color
        layer.enabled: true
        layer.effect: ShaderEffect {
            fragmentShader: "varying highp vec2 qt_TexCoord0; uniform sampler2D source; uniform lowp float qt_Opacity; void main() { highp vec2 p = qt_TexCoord0; highp vec2 a = vec2(.65,.66); highp vec2 b = vec2(.94,.66); highp vec2 c = vec2(.795,.84); highp vec2 ab=b-a; highp vec2 bc=c-b; highp vec2 ca=a-c; highp vec2 pa=p-a; highp vec2 pb=p-b; highp vec2 pc=p-c; highp float d=min(length(pa-ab*clamp(dot(pa,ab)/dot(ab,ab),0.,1.)),min(length(pb-bc*clamp(dot(pb,bc)/dot(bc,bc),0.,1.)),length(pc-ca*clamp(dot(pc,ca)/dot(ca,ca),0.,1.)))); highp float s1=ab.x*pa.y-ab.y*pa.x; highp float s2=bc.x*pb.y-bc.y*pb.x; highp float s3=ca.x*pc.y-ca.y*pc.x; highp float outside=(s1>=0. && s2>=0. && s3>=0.)?0.:1.; gl_FragColor=texture2D(source,p)*smoothstep(.038,.05,d)*outside*qt_Opacity; }"
        }
    }
    Canvas {
        id: arrow
        anchors.fill: parent
        onPaint: {
            var c = getContext("2d"); c.reset(); c.scale(width / 100, height / 100)
            c.beginPath(); c.moveTo(65, 66); c.lineTo(94, 66); c.lineTo(79.5, 84); c.closePath()
            c.fillStyle = glyph.color; c.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    onColorChanged: arrow.requestPaint()
}
