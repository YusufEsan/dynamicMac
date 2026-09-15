import Foundation
import AppKit
import SwiftUI

public struct AudioAppInfo: Identifiable, Equatable {
    public let id: String
    public let bundleId: String
    public let name: String
    public let icon: String
    public let iconColor: Color
    public var volume: Double
    public var isMuted: Bool
    
    public init(id: String, bundleId: String, name: String, icon: String, iconColor: Color, volume: Double = 80.0, isMuted: Bool = false) {
        self.id = id
        self.bundleId = bundleId
        self.name = name
        self.icon = icon
        self.iconColor = iconColor
        self.volume = volume
        self.isMuted = isMuted
    }
}

@Observable
public final class AudioMixerManager {
    public static let shared = AudioMixerManager()
    
    public var masterVolume: Double = 75.0
    public var isMasterMuted: Bool = false
    
    // Dynamic App List
    public var activeApps: [AudioAppInfo] = []
    
    // Per-app volume memory
    private var volumeStore: [String: Double] = [:]
    private var muteStore: [String: Bool] = [:]
    
    private var pollTimer: Timer?
    private var isUpdating = false
    
    // Total count including master
    public var activeAppCount: Int {
        return 1 + activeApps.count
    }
    
    private init() {
        startPolling()
        fetchVolumes()
    }
    
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.fetchVolumes()
        }
    }
    
    public func fetchVolumes() {
        guard !isUpdating else { return }
        isUpdating = true
        
        // 1. Detect open supported apps
        let supportedApps: [(id: String, bundleId: String, name: String, icon: String, color: Color)] = [
            ("chrome", "com.google.Chrome", "Google Chrome", "play.tv.fill", Color(red: 0.95, green: 0.35, blue: 0.35)),
            ("arc", "company.thebrowser.Browser", "Arc Browser", "globe", Color(red: 0.35, green: 0.55, blue: 0.95)),
            ("brave", "com.brave.Browser", "Brave Browser", "shield.fill", Color(red: 0.98, green: 0.45, blue: 0.15)),
            ("safari", "com.apple.Safari", "Safari", "safari.fill", Color(red: 0.20, green: 0.65, blue: 1.0)),
            ("spotify", "com.spotify.client", "Spotify", "waveform", Color(red: 0.11, green: 0.84, blue: 0.38)),
            ("music", "com.apple.Music", "Apple Music", "music.note", Color(red: 0.96, green: 0.30, blue: 0.60)),
            ("podcasts", "com.apple.podcasts", "Apple Podcasts", "antenna.radiowaves.left.and.right", Color(red: 0.65, green: 0.35, blue: 0.95)),
            ("quicktime", "com.apple.QuickTimePlayerX", "QuickTime Player", "play.rectangle.fill", Color(red: 0.20, green: 0.70, blue: 0.90)),
            ("vlc", "org.videolan.vlc", "VLC Media Player", "cone.fill", Color(red: 1.0, green: 0.55, blue: 0.0)),
            ("iina", "com.colliderli.iina", "IINA Player", "play.circle.fill", Color(red: 0.40, green: 0.75, blue: 0.95))
        ]
        
        var detected: [AudioAppInfo] = []
        for app in supportedApps {
            if isAppRunning(app.bundleId) {
                let savedVol = volumeStore[app.id] ?? 80.0
                let savedMute = muteStore[app.id] ?? false
                detected.append(AudioAppInfo(
                    id: app.id,
                    bundleId: app.bundleId,
                    name: app.name,
                    icon: app.icon,
                    iconColor: app.color,
                    volume: savedVol,
                    isMuted: savedMute
                ))
            }
        }
        
        // 2. Fetch system volume & native app volumes
        let script = """
        set outVol to output volume of (get volume settings)
        set outMuted to output muted of (get volume settings)
        set sVol to -1
        set mVol to -1
        
        if application "Spotify" is running then
            try
                tell application "Spotify" to set sVol to sound volume
            end try
        end if
        
        if application "Music" is running then
            try
                tell application "Music" to set mVol to sound volume
            end try
        end if
        
        return (outVol as string) & "|||" & (outMuted as string) & "|||" & (sVol as string) & "|||" & (mVol as string)
        """
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var error: NSDictionary?
            var sysVol = 75.0
            var sysMute = false
            var sVol = -1.0
            var mVol = -1.0
            
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)
                if error == nil, let val = output.stringValue {
                    let parts = val.components(separatedBy: "|||")
                    if parts.count >= 4 {
                        sysVol = Double(parts[0]) ?? 75.0
                        sysMute = (parts[1].lowercased() == "true")
                        sVol = Double(parts[2]) ?? -1.0
                        mVol = Double(parts[3]) ?? -1.0
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.masterVolume = sysVol
                self.isMasterMuted = sysMute
                
                // Update detected list with live volumes
                for i in 0..<detected.count {
                    if detected[i].id == "spotify" && sVol >= 0 {
                        detected[i].volume = sVol
                        self.volumeStore["spotify"] = sVol
                    } else if detected[i].id == "music" && mVol >= 0 {
                        detected[i].volume = mVol
                        self.volumeStore["music"] = mVol
                    }
                }
                
                self.activeApps = detected
                self.isUpdating = false
            }
        }
    }
    
    // MARK: - Master Volume
    public func setMasterVolume(_ volume: Double) {
        masterVolume = max(0, min(100, volume))
        isMasterMuted = (masterVolume == 0)
        let script = "set volume output volume \(Int(masterVolume))"
        executeScriptAsync(script)
    }
    
    public func toggleMasterMute() {
        isMasterMuted.toggle()
        let script = "set volume output muted \(isMasterMuted)"
        executeScriptAsync(script)
    }
    
    // MARK: - App Specific Volume Control
    public func setAppVolume(id: String, volume: Double) {
        let clamped = max(0, min(100, volume))
        volumeStore[id] = clamped
        muteStore[id] = (clamped == 0)
        
        if let idx = activeApps.firstIndex(where: { $0.id == id }) {
            activeApps[idx].volume = clamped
            activeApps[idx].isMuted = (clamped == 0)
        }
        
        switch id {
        case "chrome":
            setChromiumVolume(appName: "Google Chrome", volume: clamped)
        case "arc":
            setChromiumVolume(appName: "Arc", volume: clamped)
        case "brave":
            setChromiumVolume(appName: "Brave Browser", volume: clamped)
        case "safari":
            setSafariVolume(volume: clamped)
        case "spotify":
            setSpotifyVolume(clamped)
        case "music":
            setMusicVolume(clamped)
        case "podcasts":
            setPodcastsVolume(clamped)
        case "quicktime":
            setQuickTimeVolume(clamped)
        case "vlc":
            setVLCVolume(clamped)
        case "iina":
            setIINAVolume(clamped)
        default:
            break
        }
    }
    
    public func toggleAppMute(id: String) {
        guard let idx = activeApps.firstIndex(where: { $0.id == id }) else { return }
        let isMuted = activeApps[idx].isMuted || activeApps[idx].volume == 0
        if isMuted {
            let restore = volumeStore[id] ?? 80.0
            let target = restore > 0 ? restore : 80.0
            setAppVolume(id: id, volume: target)
        } else {
            volumeStore[id] = activeApps[idx].volume
            setAppVolume(id: id, volume: 0)
        }
    }
    
    // MARK: - App Script Implementations
    private func setChromiumVolume(appName: String, volume: Double) {
        let fraction = volume / 100.0
        let intVol = Int(volume)
        let isMuted = (volume == 0)
        
        // Fast targeted script: active tabs + media URL tabs
        let script = """
        tell application "\(appName)"
            if it is running then
                repeat with w in windows
                    try
                        execute (active tab of w) javascript "(() => { const v = document.querySelectorAll(\\"video, audio\\"); v.forEach(function(m){ m.volume = \(fraction); m.muted = \(isMuted); }); const p = document.getElementById(\\"movie_player\\"); if (p && p.setVolume) { p.setVolume(\(intVol)); if (\(isMuted)) { p.mute(); } else { p.unMute(); } } })()"
                    end try
                    repeat with t in tabs of w
                        try
                            set u to URL of t
                            if u contains "youtube.com" or u contains "twitch" or u contains "spotify" or u contains "soundcloud" or u contains "netflix" or u contains "video" or u contains "watch" or u contains "myasian" then
                                execute t javascript "(() => { const v = document.querySelectorAll(\\"video, audio\\"); v.forEach(function(m){ m.volume = \(fraction); m.muted = \(isMuted); }); const p = document.getElementById(\\"movie_player\\"); if (p && p.setVolume) { p.setVolume(\(intVol)); if (\(isMuted)) { p.mute(); } else { p.unMute(); } } })()"
                            end if
                        end try
                    end repeat
                end repeat
            end if
        end tell
        """
        executeScriptAsync(script)
    }
    
    private func setSafariVolume(volume: Double) {
        let fraction = volume / 100.0
        let isMuted = (volume == 0)
        let script = """
        tell application "Safari"
            if it is running then
                repeat with w in windows
                    try
                        do JavaScript "document.querySelectorAll('video, audio').forEach(function(m){ m.volume = \(fraction); m.muted = \(isMuted); });" in current tab of w
                    end try
                end repeat
            end if
        end tell
        """
        executeScriptAsync(script)
    }
    
    private func setSpotifyVolume(_ volume: Double) {
        let script = "tell application \"Spotify\" to set sound volume to \(Int(volume))"
        executeScriptAsync(script)
    }
    
    private func setMusicVolume(_ volume: Double) {
        let script = "tell application \"Music\" to set sound volume to \(Int(volume))"
        executeScriptAsync(script)
    }
    
    private func setPodcastsVolume(_ volume: Double) {
        let script = "tell application \"Podcasts\" to set sound volume to \(Int(volume))"
        executeScriptAsync(script)
    }
    
    private func setQuickTimeVolume(_ volume: Double) {
        let fraction = volume / 100.0
        let script = """
        tell application "QuickTime Player"
            if it is running then
                try
                    if (exists document 1) then
                        set audio volume of document 1 to \(fraction)
                    end if
                end try
            end if
        end tell
        """
        executeScriptAsync(script)
    }
    
    private func setVLCVolume(_ volume: Double) {
        let vlcVol = Int((volume / 100.0) * 256.0)
        let script = """
        tell application "VLC"
            if it is running then
                try
                    set volume to \(vlcVol)
                end try
            end if
        end tell
        """
        executeScriptAsync(script)
    }
    
    private func setIINAVolume(_ volume: Double) {
        let script = """
        tell application "IINA"
            if it is running then
                try
                    set volume to \(Int(volume))
                end try
            end if
        end tell
        """
        executeScriptAsync(script)
    }
    
    private func executeScriptAsync(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: source) {
                scriptObject.executeAndReturnError(&error)
            }
        }
    }
    
    private func isAppRunning(_ bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
}

