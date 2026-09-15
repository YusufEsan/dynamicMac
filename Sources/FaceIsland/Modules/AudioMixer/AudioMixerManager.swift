import Foundation
import AppKit

@Observable
public final class AudioMixerManager {
    public static let shared = AudioMixerManager()
    
    public var masterVolume: Double = 75.0
    public var isMasterMuted: Bool = false
    
    public var spotifyVolume: Double = 80.0
    public var isSpotifyRunning: Bool = false
    
    public var musicVolume: Double = 80.0
    public var isMusicRunning: Bool = false
    
    public var chromeVolume: Double = 100.0
    public var isChromeRunning: Bool = false
    
    private var pollTimer: Timer?
    private var isUpdating = false
    
    private init() {
        startPolling()
        fetchVolumes()
    }
    
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchVolumes()
        }
    }
    
    public func fetchVolumes() {
        guard !isUpdating else { return }
        
        let spotifyActive = isAppRunning("com.spotify.client")
        let musicActive = isAppRunning("com.apple.Music")
        let chromeActive = isAppRunning("com.google.Chrome")
        
        DispatchQueue.main.async {
            self.isSpotifyRunning = spotifyActive
            self.isMusicRunning = musicActive
            self.isChromeRunning = chromeActive
        }
        
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
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)
                if error == nil, let val = output.stringValue {
                    let parts = val.components(separatedBy: "|||")
                    if parts.count >= 4 {
                        let sysVol = Double(parts[0]) ?? 75.0
                        let sysMute = (parts[1].lowercased() == "true")
                        let sVol = Double(parts[2]) ?? -1
                        let mVol = Double(parts[3]) ?? -1
                        
                        DispatchQueue.main.async {
                            self.masterVolume = sysVol
                            self.isMasterMuted = sysMute
                            if sVol >= 0 { self.spotifyVolume = sVol }
                            if mVol >= 0 { self.musicVolume = mVol }
                        }
                    }
                }
            }
        }
    }
    
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
    
    public func setSpotifyVolume(_ volume: Double) {
        spotifyVolume = max(0, min(100, volume))
        let script = "tell application \"Spotify\" to set sound volume to \(Int(spotifyVolume))"
        executeScriptAsync(script)
    }
    
    public func setMusicVolume(_ volume: Double) {
        musicVolume = max(0, min(100, volume))
        let script = "tell application \"Music\" to set sound volume to \(Int(musicVolume))"
        executeScriptAsync(script)
    }
    
    public func setChromeVolume(_ volume: Double) {
        chromeVolume = max(0, min(100, volume))
        let fraction = chromeVolume / 100.0
        let script = """
        tell application "Google Chrome"
            if it is running then
                try
                    execute active tab of front window javascript "let media = document.querySelectorAll('video, audio'); media.forEach(m => m.volume = \(fraction));"
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
