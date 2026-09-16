import SwiftUI
import AppKit

@main
struct FaceIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("FaceIsland", systemImage: "faceid") {
            Button("Ayarlar...") {
                NotificationCenter.default.post(name: NSNotification.Name("FaceIsland_OpenInIslandSettings"), object: nil)
                IslandContentProvider.shared.expand(to: .faceID)
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Çıkış") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setlinebuf(stdout)
        setlinebuf(stderr)
        print("🚀 FaceIsland launched successfully (PID: \(ProcessInfo.processInfo.processIdentifier))")
        fflush(stdout)
        AppLogger.info("🚀 FaceIsland launched successfully", category: .general)
        
        DispatchQueue.main.async {
            // Check initial permissions
            PermissionManager.shared.checkAll()
            
            // Initialize Auto Unlock and Screen Monitor
            _ = AutoUnlocker.shared
            _ = ScreenLockMonitor.shared
            
            // Initialize Window Switcher global hotkey listener
            WindowSwitcherController.shared.setup()
            
            // Apply Island display style (Notch or Floating capsule)
            SettingsManager.shared.applyIslandDisplayMode()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
