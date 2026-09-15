import Foundation
import ServiceManagement
import AppKit

@Observable
public final class SettingsManager {
    public static let shared = SettingsManager()
    
    public var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "FaceIsland_LaunchAtLogin") }
        set {
            UserDefaults.standard.set(newValue, forKey: "FaceIsland_LaunchAtLogin")
            toggleLaunchAtLogin(newValue)
        }
    }
    
    public var forceFloatingCapsule: Bool {
        get { UserDefaults.standard.bool(forKey: "FaceIsland_ForceFloatingCapsule") }
        set {
            UserDefaults.standard.set(newValue, forKey: "FaceIsland_ForceFloatingCapsule")
            applyIslandDisplayMode()
        }
    }
    
    public var autoUnlockEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "FaceIsland_AutoUnlockEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "FaceIsland_AutoUnlockEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "FaceIsland_AutoUnlockEnabled")
            AutoUnlocker.shared.isAutoUnlockEnabled = newValue
        }
    }
    
    public var faceIDThreshold: Double {
        get {
            let val = UserDefaults.standard.double(forKey: "FaceIsland_FaceIDThreshold")
            return val == 0 ? 0.78 : val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "FaceIsland_FaceIDThreshold")
            FaceRecognitionManager.shared.recognitionThreshold = Float(newValue)
        }
    }
    
    public var clipboardRetentionDays: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "FaceIsland_ClipboardRetentionDays")
            return val == 0 ? 7 : val
        }
        set {
            ClipboardManager.shared.updateRetentionDays(newValue)
        }
    }
    
    public var switcherHotkey: String {
        get { UserDefaults.standard.string(forKey: "FaceIsland_SwitcherHotkey") ?? "⌥ Tab" }
        set { UserDefaults.standard.set(newValue, forKey: "FaceIsland_SwitcherHotkey") }
    }
    
    public var enableNotchVideoPlayer: Bool {
        get {
            if UserDefaults.standard.object(forKey: "FaceIsland_EnableNotchVideoPlayer") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "FaceIsland_EnableNotchVideoPlayer")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "FaceIsland_EnableNotchVideoPlayer")
        }
    }
    
    private init() {
        FaceRecognitionManager.shared.recognitionThreshold = Float(faceIDThreshold)
    }
    
    private func toggleLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                AppLogger.error("Failed to update Launch at Login: \(error)", category: .general)
            }
        }
    }
    
    public func applyIslandDisplayMode() {
        if forceFloatingCapsule {
            IslandWindowController.shared.hide()
            FloatingCapsuleController.shared.show()
        } else {
            FloatingCapsuleController.shared.hide()
            IslandWindowController.shared.show()
        }
    }
}
