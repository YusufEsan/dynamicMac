import Foundation
import AppKit
import SwiftUI
import CoreImage

@Observable
public final class NowPlayingManager {
    public static let shared = NowPlayingManager()
    
    public var title: String = "Müzik Çalmıyor"
    public var artist: String = ""
    public var album: String = ""
    public var isPlaying: Bool = false
    public var duration: Double = 0.0
    public var currentPosition: Double = 0.0
    public var artwork: NSImage? = nil {
        didSet {
            extractDominantColor()
        }
    }
    public var activePlayerName: String = ""
    public var dominantColor: Color = Color.pink
    
    public var isSpotify: Bool {
        return activePlayerName.lowercased().contains("spotify")
    }
    
    public var themeColor: Color {
        return dominantColor
    }
    
    public var badgeColor: Color {
        return isSpotify ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.red
    }
    
    public var appNameDisplay: String {
        if isSpotify { return "Spotify" }
        if activePlayerName == "Music" { return "Apple Music" }
        return "Müzik"
    }
    
    private var pollTimer: Timer?
    private var isFetching = false
    private var lastArtworkQuery: String = ""
    private var artworkCache: [String: NSImage] = [:]
    
    private init() {
        startPolling()
    }
    
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPlaybackState()
        }
    }
    
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    public func refreshPlaybackState() {
        guard !isFetching else { return }
        isFetching = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { self?.isFetching = false }
            
            // Check Spotify first, then Apple Music
            if self?.isAppRunning("com.spotify.client") == true {
                self?.fetchSpotifyState()
            } else if self?.isAppRunning("com.apple.Music") == true {
                self?.fetchAppleMusicState()
            } else {
                DispatchQueue.main.async {
                    if self?.isPlaying == true {
                        self?.isPlaying = false
                        self?.title = "Müzik Çalmıyor"
                        self?.artist = ""
                        self?.artwork = nil
                        self?.dominantColor = Color.pink
                    }
                }
            }
        }
    }
    
    private func isAppRunning(_ bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    private func fetchAppleMusicState() {
        let script = """
        tell application "Music"
            if it is running then
                set pState to player state as string
                if pState is "playing" then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackDuration to duration of current track
                    set trackPosition to player position
                    return pState & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as string) & "|||" & (trackPosition as string)
                else
                    return pState
                end if
            end if
        end tell
        """
        
        executeAppleScript(script) { [weak self] result in
            guard let self = self, let result = result else { return }
            let parts = result.components(separatedBy: "|||")
            DispatchQueue.main.async {
                if parts.count >= 6 && parts[0] == "playing" {
                    let newTitle = parts[1]
                    let newArtist = parts[2]
                    let newAlbum = parts[3]
                    
                    self.isPlaying = true
                    self.title = newTitle
                    self.artist = newArtist
                    self.album = newAlbum
                    self.duration = Self.parseNumeric(parts[4])
                    self.currentPosition = Self.parseNumeric(parts[5])
                    self.activePlayerName = "Music"
                    
                    self.fetchArtworkIfNeeded(title: newTitle, artist: newArtist)
                } else {
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func fetchSpotifyState() {
        let script = """
        tell application "Spotify"
            if it is running then
                set pState to player state as string
                if pState is "playing" then
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set rawDuration to duration of current track
                    set trackPosition to player position
                    set artUrl to ""
                    try
                        set artUrl to artwork url of current track
                    end try
                    return pState & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (rawDuration as string) & "|||" & (trackPosition as string) & "|||" & artUrl
                else
                    return pState
                end if
            end if
        end tell
        """
        executeAppleScript(script) { [weak self] result in
            guard let self = self, let result = result else { return }
            let parts = result.components(separatedBy: "|||")
            DispatchQueue.main.async {
                if parts.count >= 6 && parts[0] == "playing" {
                    let newTitle = parts[1]
                    let newArtist = parts[2]
                    let newAlbum = parts[3]
                    
                    self.isPlaying = true
                    self.title = newTitle
                    self.artist = newArtist
                    self.album = newAlbum
                    
                    // Spotify rawDuration is in milliseconds (e.g. 256947)
                    let rawDur = Self.parseNumeric(parts[4])
                    self.duration = rawDur > 10000 ? (rawDur / 1000.0) : rawDur
                    self.currentPosition = Self.parseNumeric(parts[5])
                    self.activePlayerName = "Spotify"
                    
                    if parts.count > 6 && !parts[6].isEmpty, let url = URL(string: parts[6]) {
                        self.downloadImage(from: url)
                    } else {
                        self.fetchArtworkIfNeeded(title: newTitle, artist: newArtist)
                    }
                } else {
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func fetchArtworkIfNeeded(title: String, artist: String) {
        let queryKey = "\(title)-\(artist)"
        guard queryKey != lastArtworkQuery else { return }
        lastArtworkQuery = queryKey
        
        if let cached = artworkCache[queryKey] {
            self.artwork = cached
            return
        }
        
        let cleanTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let cleanArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(cleanTitle)+\(cleanArtist)&entity=song&limit=1") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkUrlString = (first["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100bb", with: "600x600bb"),
                  let artUrl = URL(string: artworkUrlString) else {
                return
            }
            
            self?.downloadImage(from: artUrl, cacheKey: queryKey)
        }.resume()
    }
    
    private func downloadImage(from url: URL, cacheKey: String? = nil) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.artwork = image
                if let key = cacheKey {
                    self?.artworkCache[key] = image
                }
            }
        }.resume()
    }
    
    /// Extracts dominant/average color from the current album artwork image
    private func extractDominantColor() {
        guard let image = self.artwork,
              let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            self.dominantColor = isSpotify ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.pink
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
                  let outputImage = filter.outputImage else { return }
            
            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: NSNull()])
            context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            
            let r = Double(bitmap[0]) / 255.0
            let g = Double(bitmap[1]) / 255.0
            let b = Double(bitmap[2]) / 255.0
            
            // Boost vibrancy so it glows nicely on black
            let maxC = max(r, max(g, b))
            let factor = maxC > 0 ? min(1.3, 0.85 / maxC) : 1.0
            
            let extractedColor = Color(red: min(1.0, r * factor), green: min(1.0, g * factor), blue: min(1.0, b * factor))
            
            DispatchQueue.main.async {
                self?.dominantColor = extractedColor
            }
        }
    }
    
    private func executeAppleScript(_ source: String, completion: @escaping (String?) -> Void) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                completion(output.stringValue)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
    
    public func togglePlayPause() {
        let target = activePlayerName.isEmpty ? "Music" : activePlayerName
        let script = "tell application \"\(target)\" to playpause"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(script) { _ in
                DispatchQueue.main.async {
                    self?.isPlaying.toggle()
                    self?.refreshPlaybackState()
                }
            }
        }
    }
    
    public func nextTrack() {
        let target = activePlayerName.isEmpty ? "Music" : activePlayerName
        let script = "tell application \"\(target)\" to next track"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(script) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.refreshPlaybackState()
                }
            }
        }
    }
    
    public func previousTrack() {
        let target = activePlayerName.isEmpty ? "Music" : activePlayerName
        let script = "tell application \"\(target)\" to previous track"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(script) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.refreshPlaybackState()
                }
            }
        }
    }
    
    public func seek(to position: Double) {
        self.currentPosition = max(0, min(duration, position))
        let target = activePlayerName.isEmpty ? (isSpotify ? "Spotify" : "Music") : activePlayerName
        let pos = self.currentPosition
        let script: String
        if target.lowercased().contains("spotify") {
            script = "tell application \"Spotify\" to set player position to \(pos)"
        } else {
            script = "tell application \"Music\" to set player position to \(pos)"
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(script) { _ in }
        }
    }
    
    public var formattedPosition: String {
        Self.formatTime(currentPosition)
    }
    
    public var formattedDuration: String {
        Self.formatTime(duration)
    }
    
    public static func parseNumeric(_ text: String) -> Double {
        let clean = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean) ?? 0.0
    }
    
    public static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let totalSecs = Int(seconds)
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
