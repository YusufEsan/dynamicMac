import SwiftUI
import AppKit

public final class SettingsWindowController {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func show() {
        if let existing = window {
            existing.close()
            self.window = nil
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("FaceIsland_OpenInIslandSettings"), object: nil)
        IslandContentProvider.shared.expand(to: .faceID)
    }
}
