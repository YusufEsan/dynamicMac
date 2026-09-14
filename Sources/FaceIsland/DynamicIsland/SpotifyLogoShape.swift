import SwiftUI

/// Authentic Spotify 3 curved arcs logo
public struct SpotifyLogoShape: View {
    public var size: CGFloat = 18
    public var iconColor: Color = .black
    
    public init(size: CGFloat = 18, iconColor: Color = .black) {
        self.size = size
        self.iconColor = iconColor
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            
            // Top Arc (Largest)
            var topArc = Path()
            topArc.move(to: CGPoint(x: w * 0.22, y: h * 0.42))
            topArc.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.26), control: CGPoint(x: w * 0.48, y: h * 0.22))
            context.stroke(topArc, with: .color(iconColor), style: StrokeStyle(lineWidth: w * 0.12, lineCap: .round))
            
            // Middle Arc (Medium)
            var midArc = Path()
            midArc.move(to: CGPoint(x: w * 0.26, y: h * 0.58))
            midArc.addQuadCurve(to: CGPoint(x: w * 0.74, y: h * 0.45), control: CGPoint(x: w * 0.48, y: h * 0.42))
            context.stroke(midArc, with: .color(iconColor), style: StrokeStyle(lineWidth: w * 0.11, lineCap: .round))
            
            // Bottom Arc (Smallest)
            var botArc = Path()
            botArc.move(to: CGPoint(x: w * 0.30, y: h * 0.74))
            botArc.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.64), control: CGPoint(x: w * 0.48, y: h * 0.60))
            context.stroke(botArc, with: .color(iconColor), style: StrokeStyle(lineWidth: w * 0.10, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}
