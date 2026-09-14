import Foundation
import AppKit
import CoreGraphics

public final class AutoUnlocker {
    public static let shared = AutoUnlocker()
    
    public var isAutoUnlockEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "FaceIsland_AutoUnlockEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "FaceIsland_AutoUnlockEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "FaceIsland_AutoUnlockEnabled") }
    }
    
    private init() {
        setupUnlockPipeline()
    }
    
    private func setupUnlockPipeline() {
        ScreenLockMonitor.shared.onScreenWake = { [weak self] in
            guard let self = self, self.isAutoUnlockEnabled else { return }
            self.prepareIslandForLockOrWake()
            self.triggerFaceScanForUnlock()
        }
        
        ScreenLockMonitor.shared.onScreenLocked = { [weak self] in
            guard let self = self, self.isAutoUnlockEnabled else { return }
            self.prepareIslandForLockOrWake()
            self.triggerFaceScanForUnlock()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(faceRecognizedReceived(_:)),
            name: FaceRecognitionManager.faceRecognizedNotification,
            object: nil
        )
    }
    
    public func prepareIslandForLockOrWake() {
        DispatchQueue.main.async {
            SettingsManager.shared.applyIslandDisplayMode()
        }
    }
    
    @objc private func faceRecognizedReceived(_ notification: Notification) {
        guard isAutoUnlockEnabled else { return }
        executeUnlock()
    }
    
    public func triggerFaceScanForUnlock() {
        guard isAutoUnlockEnabled else { return }
        prepareIslandForLockOrWake()
        AppLogger.info("Triggering Face scan on wake/launch", category: .unlock)
        FaceRecognitionManager.shared.startRecognition()
    }
    
    public func executeUnlock() {
        guard let password = KeychainHelper.shared.getPassword() else {
            AppLogger.error("Cannot unlock: No password stored in Keychain", category: .unlock)
            return
        }
        
        AppLogger.info("Attempting automatic screen unlock...", category: .unlock)
        
        DispatchQueue.global(qos: .userInteractive).async {
            // Send keystrokes via CGEvent to unlock macOS lock screen
            for char in password {
                let uniChar = Array(String(char).utf16)
                if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                    eventDown.keyboardSetUnicodeString(stringLength: uniChar.count, unicodeString: uniChar)
                    eventDown.post(tap: .cghidEventTap)
                }
                usleep(15000)
                if let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                    eventUp.keyboardSetUnicodeString(stringLength: uniChar.count, unicodeString: uniChar)
                    eventUp.post(tap: .cghidEventTap)
                }
                usleep(15000)
            }
            
            // Post Return Key (virtual key 36 / 0x24)
            usleep(50000)
            let returnDown = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true)
            returnDown?.post(tap: .cghidEventTap)
            usleep(20000)
            let returnUp = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false)
            returnUp?.post(tap: .cghidEventTap)
            
            AppLogger.info("Unlock keystrokes dispatched successfully", category: .unlock)
        }
    }
}
