import Foundation
import AppKit

@Observable
public final class ScreenLockMonitor {
    public static let shared = ScreenLockMonitor()
    
    public var isScreenLocked: Bool = false
    public var onScreenLocked: (() -> Void)?
    public var onScreenUnlocked: (() -> Void)?
    public var onScreenWake: (() -> Void)?
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        let dnc = DistributedNotificationCenter.default()
        
        // Lock screen events
        dnc.addObserver(
            self,
            selector: #selector(screenLockedReceived),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        dnc.addObserver(
            self,
            selector: #selector(screenUnlockedReceived),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // Screensaver events
        dnc.addObserver(
            self,
            selector: #selector(screensaverStartedReceived),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )
        
        dnc.addObserver(
            self,
            selector: #selector(screensaverStoppedReceived),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )
        
        let ws = NSWorkspace.shared.notificationCenter
        
        // Display sleep / wake
        ws.addObserver(
            self,
            selector: #selector(screenWokeReceived),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        ws.addObserver(
            self,
            selector: #selector(screenSleptReceived),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        // System sleep / wake
        ws.addObserver(
            self,
            selector: #selector(screenWokeReceived),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Session switch / fast user lock
        ws.addObserver(
            self,
            selector: #selector(sessionResignedReceived),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        
        ws.addObserver(
            self,
            selector: #selector(sessionActiveReceived),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func screenLockedReceived() {
        isScreenLocked = true
        AppLogger.info("🔒 Screen locked detected", category: .unlock)
        onScreenLocked?()
    }
    
    @objc private func screenUnlockedReceived() {
        isScreenLocked = false
        AppLogger.info("🔓 Screen unlocked detected", category: .unlock)
        onScreenUnlocked?()
    }
    
    @objc private func screensaverStartedReceived() {
        isScreenLocked = true
        AppLogger.info("🖥️ Screensaver started", category: .unlock)
        onScreenLocked?()
    }
    
    @objc private func screensaverStoppedReceived() {
        AppLogger.info("🖥️ Screensaver stopped / waking", category: .unlock)
        onScreenWake?()
    }
    
    @objc private func screenSleptReceived() {
        isScreenLocked = true
        AppLogger.info("🌙 Screen sleep detected", category: .unlock)
    }
    
    @objc private func screenWokeReceived() {
        AppLogger.info("☀️ Screen wake detected", category: .unlock)
        onScreenWake?()
    }
    
    @objc private func sessionResignedReceived() {
        isScreenLocked = true
        AppLogger.info("🔒 User session resigned active", category: .unlock)
        onScreenLocked?()
    }
    
    @objc private func sessionActiveReceived() {
        AppLogger.info("👤 User session became active", category: .unlock)
        onScreenWake?()
    }
}
