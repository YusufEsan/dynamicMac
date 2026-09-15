import SwiftUI

public enum AnimationConstants {
    /// Super liquid bouncy spring for Apple-like Island morphing
    public static let islandMorphSpring = Animation.interpolatingSpring(mass: 0.7, stiffness: 250, damping: 14.5, initialVelocity: 6)
    
    /// Smooth fluid expansion
    public static let smoothExpansion = Animation.spring(response: 0.32, dampingFraction: 0.68, blendDuration: 0.1)
    
    /// Quick snappy feedback for button presses
    public static let quickInteractive = Animation.spring(response: 0.18, dampingFraction: 0.6)
    
    /// Face ID pulse radar timing
    public static let radarPulse = Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    
    /// Continuous 360 rotation
    public static let continuousRotation = Animation.linear(duration: 4.0).repeatForever(autoreverses: false)
    
    /// Laser scanning sweep
    public static let scanSweep = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
    
    /// Sound equalizer bar bounce
    public static let equalizerBounce = Animation.easeInOut(duration: 0.35).repeatForever(autoreverses: true)
}
