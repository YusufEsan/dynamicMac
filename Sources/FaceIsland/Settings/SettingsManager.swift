import Foundation
import ServiceManagement
import AppKit

public enum NotchAlignment: String, CaseIterable, Identifiable {
    case left = "left"
    case center = "center"
    case right = "right"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .left: return "Sol"
        case .center: return "Orta"
        case .right: return "Sağ"
        }
    }
    
    public var iconName: String {
        switch self {
        case .left: return "align.horizontal.left"
        case .center: return "align.horizontal.center"
        case .right: return "align.horizontal.right"
        }
    }
}

@Observable
public final class SettingsManager {
    public static let shared = SettingsManager()
    
    public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "FaceIsland_LaunchAtLogin")
            toggleLaunchAtLogin(launchAtLogin)
        }
    }
    
    public var forceFloatingCapsule: Bool {
        didSet {
            UserDefaults.standard.set(forceFloatingCapsule, forKey: "FaceIsland_ForceFloatingCapsule")
            applyIslandDisplayMode()
        }
    }
    
    public var notchAlignment: NotchAlignment {
        didSet {
            UserDefaults.standard.set(notchAlignment.rawValue, forKey: "FaceIsland_NotchAlignment")
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    IslandWindowController.shared.repositionWindow()
                }
            } else {
                DispatchQueue.main.async {
                    IslandWindowController.shared.repositionWindow()
                }
            }
        }
    }
    
    public var autoUnlockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoUnlockEnabled, forKey: "FaceIsland_AutoUnlockEnabled")
            AutoUnlocker.shared.isAutoUnlockEnabled = autoUnlockEnabled
        }
    }
    
    public var faceIDThreshold: Double {
        didSet {
            UserDefaults.standard.set(faceIDThreshold, forKey: "FaceIsland_FaceIDThreshold")
            FaceRecognitionManager.shared.recognitionThreshold = Float(faceIDThreshold)
        }
    }
    
    public var clipboardRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(clipboardRetentionDays, forKey: "FaceIsland_ClipboardRetentionDays")
            ClipboardManager.shared.updateRetentionDays(clipboardRetentionDays)
        }
    }
    
    public var switcherHotkey: String {
        didSet {
            UserDefaults.standard.set(switcherHotkey, forKey: "FaceIsland_SwitcherHotkey")
        }
    }
    
    public var enableNotchVideoPlayer: Bool {
        didSet {
            UserDefaults.standard.set(enableNotchVideoPlayer, forKey: "FaceIsland_EnableNotchVideoPlayer")
        }
    }
    
    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "FaceIsland_LaunchAtLogin")
        self.forceFloatingCapsule = UserDefaults.standard.bool(forKey: "FaceIsland_ForceFloatingCapsule")
        
        let rawAlign = UserDefaults.standard.string(forKey: "FaceIsland_NotchAlignment") ?? "center"
        self.notchAlignment = NotchAlignment(rawValue: rawAlign) ?? .center
        
        if UserDefaults.standard.object(forKey: "FaceIsland_AutoUnlockEnabled") == nil {
            self.autoUnlockEnabled = true
        } else {
            self.autoUnlockEnabled = UserDefaults.standard.bool(forKey: "FaceIsland_AutoUnlockEnabled")
        }
        
        let valThresh = UserDefaults.standard.double(forKey: "FaceIsland_FaceIDThreshold")
        self.faceIDThreshold = valThresh == 0 ? 0.78 : valThresh
        
        let valRet = UserDefaults.standard.integer(forKey: "FaceIsland_ClipboardRetentionDays")
        self.clipboardRetentionDays = valRet == 0 ? 7 : valRet
        
        self.switcherHotkey = UserDefaults.standard.string(forKey: "FaceIsland_SwitcherHotkey") ?? "⌥ Tab"
        
        if UserDefaults.standard.object(forKey: "FaceIsland_EnableNotchVideoPlayer") == nil {
            self.enableNotchVideoPlayer = true
        } else {
            self.enableNotchVideoPlayer = UserDefaults.standard.bool(forKey: "FaceIsland_EnableNotchVideoPlayer")
        }
        
        FaceRecognitionManager.shared.recognitionThreshold = Float(self.faceIDThreshold)
    }
    
    private func toggleLaunchAtLogin(_ enable: Bool) {
        Task.detached(priority: .userInitiated) {
            if #available(macOS 13.0, *) {
                guard Bundle.main.bundleURL.pathExtension == "app" else {
                    AppLogger.info("Launch at login skipped for standalone executable build.", category: .general)
                    return
                }
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
