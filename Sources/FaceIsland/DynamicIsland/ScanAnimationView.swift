import SwiftUI

public struct ScanAnimationView: View {
    @State private var scanOffset: CGFloat = -30
    @State private var pulseScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0.4
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Subtle glowing background
            Circle()
                .fill(RadialGradient(
                    colors: [Color.blue.opacity(0.35), Color.clear],
                    center: .center,
                    startRadius: 2,
                    endRadius: 40
                ))
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)
            
            // Sweeping laser line
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.clear, Color.cyan.opacity(0.8), Color.blue, Color.cyan.opacity(0.8), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 2)
                .offset(y: scanOffset)
                .blur(radius: 0.5)
        }
        .onAppear {
            withAnimation(AnimationConstants.scanSweep) {
                scanOffset = 30
            }
            withAnimation(AnimationConstants.radarPulse) {
                pulseScale = 1.25
                glowOpacity = 0.8
            }
        }
    }
}
