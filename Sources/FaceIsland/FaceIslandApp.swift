import SwiftUI
import AppKit

@main
struct FaceIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("FaceIsland", systemImage: "oval.portrait") {
            Button("Toggle Dynamic Island") {
                IslandContentProvider.shared.toggleExpand()
            }
            
            Button("Alt+Tab Window Switcher") {
                WindowSwitcherController.shared.show()
            }
            
            Divider()
            
            Button("Settings...") {
                SettingsWindowController.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit FaceIsland") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        
        Settings {
            SettingsView()
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
            
            // On launch: only trigger Face ID unlock workflow if screen is locked
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if ScreenLockMonitor.shared.isScreenLocked && FaceRecognitionManager.shared.isEnrolled {
                    AutoUnlocker.shared.triggerFaceScanForUnlock()
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
