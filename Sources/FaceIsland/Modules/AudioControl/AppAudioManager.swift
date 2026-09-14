import Foundation
import AppKit
import CoreAudio
import AudioToolbox

@Observable
public final class AppAudioManager {
    public static let shared = AppAudioManager()
    
    public var activeApps: [AppAudioItem] = []
    public var masterVolume: Float = 0.8
    public var isMasterMuted: Bool = false
    
    private var scanTimer: Timer?
    private var volumeStore: [String: Float] = [:]
    
    private init() {
        refreshActiveApps()
        startPeriodicScan()
    }
    
    public func startPeriodicScan() {
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshActiveApps()
        }
    }
    
    public func refreshActiveApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        var list: [AppAudioItem] = []
        
        let mediaKeywords = ["music", "spotify", "safari", "chrome", "firefox", "brave", "edge", "arc", "slack", "discord", "zoom", "teams", "telegram", "quicktime", "vlc", "podcasts", "youtube", "facetime"]
        
        for app in runningApps where app.activationPolicy == .regular {
            guard let name = app.localizedName, let bundleId = app.bundleIdentifier else { continue }
            
            let isMediaCandidate = mediaKeywords.contains { kw in
                name.localizedCaseInsensitiveContains(kw) || bundleId.localizedCaseInsensitiveContains(kw)
            }
            
            if isMediaCandidate {
                let savedVol = volumeStore[bundleId] ?? 0.85
                list.append(AppAudioItem(
                    id: app.processIdentifier,
                    name: name,
                    bundleIdentifier: bundleId,
                    volume: savedVol,
                    isMuted: savedVol == 0.0,
                    icon: app.icon
                ))
            }
        }
        
        DispatchQueue.main.async {
            self.activeApps = list
        }
    }
    
    public func setVolume(for app: AppAudioItem, volume: Float) {
        if let idx = activeApps.firstIndex(where: { $0.id == app.id }) {
            activeApps[idx].volume = volume
            activeApps[idx].isMuted = (volume <= 0.01)
            if let bundleId = app.bundleIdentifier {
                volumeStore[bundleId] = volume
            }
            AppLogger.info("Adjusted volume for \(app.name) to \(Int(volume * 100))%", category: .audio)
        }
    }
    
    public func toggleMute(for app: AppAudioItem) {
        if let idx = activeApps.firstIndex(where: { $0.id == app.id }) {
            let wasMuted = activeApps[idx].isMuted
            if wasMuted {
                let restored = volumeStore[app.bundleIdentifier ?? ""] ?? 0.75
                activeApps[idx].volume = max(restored, 0.2)
                activeApps[idx].isMuted = false
            } else {
                activeApps[idx].volume = 0.0
                activeApps[idx].isMuted = true
            }
        }
    }
}
