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
    
    private var basePosition: Double = 0.0
    private var lastTimestamp: Date = Date()
    private var playbackRate: Double = 0.0
    
    public var currentPosition: Double {
        get {
            if isPlaying && playbackRate > 0 && duration > 0 {
                let elapsedSinceUpdate = Date().timeIntervalSince(lastTimestamp)
                return min(duration, max(0.0, basePosition + (elapsedSinceUpdate * playbackRate)))
            }
            return basePosition
        }
        set {
            basePosition = max(0.0, min(duration > 0 ? duration : 3600.0, newValue))
            lastTimestamp = Date()
        }
    }
    
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
    
    public var isYouTube: Bool {
        return activePlayerName.lowercased().contains("youtube") || artist.lowercased().contains("youtube") || album.lowercased().contains("youtube")
    }
    
    public var themeColor: Color {
        return dominantColor
    }
    
    public var badgeColor: Color {
        if isSpotify { return Color(red: 0.11, green: 0.84, blue: 0.38) }
        if isYouTube { return Color.red }
        return Color.red
    }
    
    public var appNameDisplay: String {
        if isSpotify { return "Spotify" }
        if isYouTube { return "YouTube" }
        if activePlayerName == "Music" { return "Apple Music" }
        if !activePlayerName.isEmpty { return activePlayerName }
        return "Medya"
    }
    
    // MARK: - Private MediaRemote Function Pointers
    private typealias MRMediaRemoteGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRMediaRemoteSendCommandFn = @convention(c) (Int32, CFDictionary?) -> Bool
    private typealias MRMediaRemoteSetElapsedTimeFn = @convention(c) (Double) -> Void
    private typealias MRMediaRemoteRegisterFn = @convention(c) (DispatchQueue) -> Void
    
    private var getInfoFn: MRMediaRemoteGetNowPlayingInfoFn?
    private var isPlayingFn: MRMediaRemoteGetNowPlayingApplicationIsPlayingFn?
    private var sendCommandFn: MRMediaRemoteSendCommandFn?
    private var setElapsedTimeFn: MRMediaRemoteSetElapsedTimeFn?
    
    private var pollTimer: Timer?
    private var isFetching = false
    private var lastArtworkQuery: String = ""
    private var artworkCache: [String: NSImage] = [:]
    
    private init() {
        setupMediaRemote()
        startPolling()
    }
    
    private func setupMediaRemote() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            return
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfoFn = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            isPlayingFn = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommandFn = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            setElapsedTimeFn = unsafeBitCast(sym, to: MRMediaRemoteSetElapsedTimeFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let reg = unsafeBitCast(sym, to: MRMediaRemoteRegisterFn.self)
            reg(DispatchQueue.main)
        }
        
        // Listen to macOS Now Playing notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPlaybackState()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPlaybackState()
        }
    }
    
    public func startPolling() {
        pollTimer?.invalidate()
        // Poll every 0.8s for smooth slider updates
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
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
        
        if let getInfo = getInfoFn {
            getInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] dict in
                guard let self = self else { return }
                defer { self.isFetching = false }
                
                if let dict = dict as? [String: Any],
                   let trackTitle = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
                   !trackTitle.isEmpty {
                    
                    let trackArtist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                    let trackAlbum = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                    let trackDuration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
                    let trackElapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
                    let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
                    let infoTimestamp = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date ?? Date()
                    let isMediaPlaying = (rate > 0)
                    
                    // Artwork data
                    var newImage: NSImage? = nil
                    if let rawData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                        newImage = NSImage(data: rawData)
                    }
                    
                    // Detect Source App
                    var detectedApp = "Medya"
                    let lowerArtist = trackArtist.lowercased()
                    let lowerTitle = trackTitle.lowercased()
                    
                    if lowerArtist.contains("youtube") || lowerTitle.contains("youtube") || trackAlbum.lowercased().contains("youtube") {
                        detectedApp = "YouTube"
                    } else if self.isAppRunning("com.spotify.client") && (trackDuration > 0 && !lowerArtist.contains("youtube")) {
                        detectedApp = "Spotify"
                    } else if self.isAppRunning("com.apple.Music") {
                        detectedApp = "Music"
                    } else if self.isAppRunning("com.google.Chrome") {
                        detectedApp = "YouTube"
                    }
                    
                    DispatchQueue.main.async {
                        self.isPlaying = isMediaPlaying
                        self.title = trackTitle
                        self.artist = trackArtist.isEmpty ? (detectedApp == "YouTube" ? "YouTube Video" : "") : trackArtist
                        self.album = trackAlbum
                        self.duration = trackDuration
                        self.basePosition = trackElapsed
                        self.lastTimestamp = infoTimestamp
                        self.playbackRate = rate
                        self.activePlayerName = detectedApp
                        
                        if let img = newImage {
                            self.artwork = img
                        } else if self.artwork == nil {
                            self.fetchArtworkIfNeeded(title: trackTitle, artist: trackArtist)
                        }
                    }
                } else {
                    // Fallback to AppleScript checks
                    self.fallbackAppleScriptCheck()
                }
            }
        } else {
            fallbackAppleScriptCheck()
        }
    }
    
    private func fallbackAppleScriptCheck() {
        defer { self.isFetching = false }
        
        // 1. Spotify
        if isAppRunning("com.spotify.client") {
            fetchSpotifyState()
        }
        // 2. Apple Music
        else if isAppRunning("com.apple.Music") {
            fetchAppleMusicState()
        }
        // 3. Google Chrome
        else if isAppRunning("com.google.Chrome") {
            fetchChromeMediaState()
        } else {
            DispatchQueue.main.async { [weak self] in
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
    
    private func isAppRunning(_ bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    private func fetchChromeMediaState() {
        let script = """
        tell application "Google Chrome"
            if it is running then
                set winList to windows
                repeat with w in winList
                    set tabList to tabs of w
                    repeat with t in tabList
                        set tTitle to title of t
                        set tUrl to URL of t
                        if tTitle contains "YouTube" or tUrl contains "youtube.com" then
                            return "playing|||" & tTitle & "|||" & tUrl
                        end if
                    end repeat
                end repeat
            end if
            return "stopped"
        end tell
        """
        executeAppleScript(script) { [weak self] result in
            guard let self = self, let result = result else { return }
            self.handleBrowserResult(result: result, browserName: "Chrome")
        }
    }
    
    private func handleBrowserResult(result: String, browserName: String) {
        let parts = result.components(separatedBy: "|||")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if parts.count >= 3 && parts[0] == "playing" {
                var cleanTitle = parts[1]
                    .replacingOccurrences(of: " - YouTube", with: "")
                    .replacingOccurrences(of: "YouTube - ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanTitle.hasPrefix("(") && cleanTitle.contains(") ") {
                    if let endIdx = cleanTitle.firstIndex(of: ")") {
                        cleanTitle = String(cleanTitle[cleanTitle.index(after: endIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                self.isPlaying = true
                self.title = cleanTitle.isEmpty ? "YouTube Video" : cleanTitle
                self.artist = "YouTube (\(browserName))"
                self.album = "Web Medya"
                self.activePlayerName = "YouTube"
                if self.duration == 0 { self.duration = 180 }
                if self.basePosition == 0 { self.basePosition = 45 }
                
                let urlString = parts[2]
                if let vIdx = urlString.range(of: "v=") {
                    let idSubstring = urlString[vIdx.upperBound...]
                    let videoId = String(idSubstring.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" }))
                    if !videoId.isEmpty, let thumbUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg") {
                        self.downloadImage(from: thumbUrl, cacheKey: videoId)
                    }
                }
            } else {
                self.isPlaying = false
            }
        }
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
                    self.basePosition = Self.parseNumeric(parts[5])
                    self.lastTimestamp = Date()
                    self.playbackRate = 1.0
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
                    
                    let rawDur = Self.parseNumeric(parts[4])
                    self.duration = rawDur > 10000 ? (rawDur / 1000.0) : rawDur
                    self.basePosition = Self.parseNumeric(parts[5])
                    self.lastTimestamp = Date()
                    self.playbackRate = 1.0
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
    
    // MARK: - Playback Controls
    public func togglePlayPause() {
        if let sendCommand = sendCommandFn {
            // kMRTogglePlayPause = 2
            _ = sendCommand(2, nil)
        }
        Self.postHardwareMediaKey(keyCode: 16) // NX_KEYTYPE_PLAY
        
        DispatchQueue.main.async {
            self.isPlaying.toggle()
            self.playbackRate = self.isPlaying ? 1.0 : 0.0
            self.lastTimestamp = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshPlaybackState()
        }
    }
    
    public func nextTrack() {
        if let sendCommand = sendCommandFn {
            // kMRNextTrack = 4
            _ = sendCommand(4, nil)
        }
        Self.postHardwareMediaKey(keyCode: 19) // NX_KEYTYPE_FAST
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshPlaybackState()
        }
    }
    
    public func previousTrack() {
        if let sendCommand = sendCommandFn {
            // kMRPreviousTrack = 5
            _ = sendCommand(5, nil)
        }
        Self.postHardwareMediaKey(keyCode: 20) // NX_KEYTYPE_REWIND
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshPlaybackState()
        }
    }
    
    public func seek(to position: Double) {
        let pos = max(0, min(duration > 0 ? duration : 3600.0, position))
        self.currentPosition = pos
        
        if let setElapsedTime = setElapsedTimeFn {
            setElapsedTime(pos)
        }
        
        if let sendCommand = sendCommandFn {
            // kMRChangePlaybackPosition = 15
            let options: [String: Any] = ["kMRMediaRemoteOptionPlaybackPosition": pos]
            _ = sendCommand(15, options as CFDictionary)
        }
        
        if isSpotify {
            let script = "tell application \"Spotify\" to set player position to \(pos)"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(script) { _ in }
            }
        } else if activePlayerName == "Music" {
            let script = "tell application \"Music\" to set player position to \(pos)"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(script) { _ in }
            }
        }
    }
    
    public static func postHardwareMediaKey(keyCode: Int32) {
        func send(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((keyCode << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            if let cg = ev?.cgEvent {
                cg.post(tap: .cghidEventTap)
            }
        }
        send(down: true)
        send(down: false)
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
