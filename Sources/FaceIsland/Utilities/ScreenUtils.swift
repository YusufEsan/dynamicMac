import AppKit
import Foundation

public final class ScreenUtils {
    public static let shared = ScreenUtils()
    private init() {}

    /// Returns whether the main display has a hardware notch
    public var hasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil
        }
        return false
    }

    /// Returns the exact frame and dimensions of the notch on the main screen if present
    public var notchFrame: CGRect? {
        guard let screen = NSScreen.main, hasNotch else { return nil }
        
        let screenFrame = screen.frame
        let topInset = screen.safeAreaInsets.top
        
        // Approximate notch width and height based on screen geometry
        let notchWidth: CGFloat = 200.0
        let notchHeight: CGFloat = topInset > 0 ? topInset : 34.0
        let notchX = screenFrame.midX - (notchWidth / 2.0)
        let notchY = screenFrame.maxY - notchHeight
        
        return CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    }

    /// Screen width & bounds
    public var mainScreenFrame: CGRect {
        return NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
