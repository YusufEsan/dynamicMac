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
            if isPlaying {
                let elapsedSinceUpdate = Date().timeIntervalSince(lastTimestamp)
                let rate = playbackRate > 0 ? playbackRate : 1.0
                let pos = basePosition + (elapsedSinceUpdate * rate)
                if duration > 0 {
                    return min(duration, max(0.0, pos))
                }
                return max(0.0, pos)
            }
            return basePosition
        }
        set {
            basePosition = max(0.0, min(duration > 0 ? duration : 7200.0, newValue))
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
    public var lastActiveUrl: String = ""
    private var youtubeDurationCache: [String: Double] = [:]
    
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
                        detectedApp = "Chrome"
                    }
                    
                    if (detectedApp == "Chrome" || detectedApp == "YouTube") && !isMediaPlaying {
                        // Browser video is paused/closed: verify actual tab media rather than stale cache
                        self.fetchChromeMediaState(mediaRemotePlaying: false)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.isPlaying = isMediaPlaying
                        self.title = trackTitle
                        self.artist = trackArtist.isEmpty ? (detectedApp == "Chrome" ? "Film / Dizi (Chrome)" : (detectedApp == "YouTube" ? "YouTube Video" : "")) : trackArtist
                        self.album = trackAlbum.isEmpty && detectedApp == "Chrome" ? "Web Medya" : trackAlbum
                        self.duration = trackDuration
                        self.basePosition = trackElapsed
                        self.lastTimestamp = infoTimestamp
                        self.playbackRate = isMediaPlaying ? (rate > 0 ? rate : 1.0) : 0.0
                        self.activePlayerName = detectedApp
                        
                        if let img = newImage {
                            self.artwork = img
                        } else if detectedApp == "Chrome" {
                            // Fetch Chrome tab URL / Favicon / JS stats
                            self.fetchChromeMediaState(mediaRemotePlaying: isMediaPlaying)
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
            fetchChromeMediaState(mediaRemotePlaying: false)
        } else {
            DispatchQueue.main.async { [weak self] in
                if self?.isPlaying == true {
                    self?.isPlaying = false
                    self?.title = "Müzik Çalmıyor"
                    self?.artist = ""
                    self?.artwork = nil
                    self?.duration = 0
                    self?.basePosition = 0
                    self?.playbackRate = 0
                    self?.dominantColor = Color.pink
                }
            }
        }
    }
    
    private func isAppRunning(_ bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }
    
    private func fetchChromeMediaState(mediaRemotePlaying: Bool = true) {
        let jsCode = "(() => { function parseT(t) { if (!t) return 0; let p = t.trim().split(':'); if (p.length === 3) return (+p[0])*3600 + (+p[1])*60 + (+p[2]); if (p.length === 2) return (+p[0])*60 + (+p[1]); return +t || 0; } let videos = Array.from(document.querySelectorAll('video, audio')); document.querySelectorAll('iframe').forEach(f => { try { if (f.contentDocument) { videos = videos.concat(Array.from(f.contentDocument.querySelectorAll('video, audio'))); } } catch(e) {} }); for (let v of videos) { if (!v.paused && v.duration && v.duration > 0 && !isNaN(v.duration)) { return Math.floor(v.currentTime) + '|||' + Math.floor(v.duration) + '|||1'; } } for (let v of videos) { if (v.paused && v.duration && v.duration > 0) { return Math.floor(v.currentTime) + '|||' + Math.floor(v.duration) + '|||0'; } } return ''; })()"
        
        let script = """
        tell application "Google Chrome"
            if it is running then
                -- 1. Check active tab of front window
                try
                    set frontWin to front window
                    set curTab to active tab of frontWin
                    set curTitle to title of curTab
                    set curUrl to URL of curTab
                    if curTitle is not "" and curTitle is not "New Tab" and curTitle is not "Yeni Sekme" and curTitle is not "Settings" then
                        set vStats to ""
                        try
                            set vStats to execute curTab javascript "\(jsCode)"
                        end try
                        if vStats is not "" then
                            return "stats|||" & curTitle & "|||" & curUrl & "|||" & vStats
                        end if
                        return "info|||" & curTitle & "|||" & curUrl
                    end if
                end try
            end if
            return "stopped"
        end tell
        """
        executeAppleScript(script) { [weak self] result in
            guard let self = self, let result = result else { return }
            self.handleBrowserResult(result: result, browserName: "Chrome", mediaRemotePlaying: mediaRemotePlaying)
        }
    }
    
    private func handleBrowserResult(result: String, browserName: String, mediaRemotePlaying: Bool) {
        let parts = result.components(separatedBy: "|||")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let status = parts.first ?? "stopped"
            
            if status == "stats" && parts.count >= 6 {
                let urlString = parts[2]
                let isMedia = Self.isMediaUrl(urlString)
                let isYT = urlString.contains("youtube.com") || parts[1].contains("YouTube")
                let rawCurr = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let rawDur = parts[4].trimmingCharacters(in: .whitespacesAndNewlines)
                let isPlayingFlag = parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
                let isVideoPlaying = (isPlayingFlag == "1")
                
                if !isMedia && !isVideoPlaying {
                    self.isPlaying = false
                    self.playbackRate = 0.0
                    self.title = "Müzik Çalmıyor"
                    self.artist = ""
                    self.artwork = nil
                    self.duration = 0.0
                    self.basePosition = 0.0
                    self.lastActiveUrl = ""
                    self.activePlayerName = ""
                    return
                }
                
                var cleanTitle = parts[1]
                    .replacingOccurrences(of: " - Google Chrome", with: "")
                    .replacingOccurrences(of: " - YouTube", with: "")
                    .replacingOccurrences(of: "YouTube - ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let pipeIdx = cleanTitle.lastIndex(of: "|") {
                    cleanTitle = String(cleanTitle[..<pipeIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if cleanTitle.hasPrefix("(") && cleanTitle.contains(") ") {
                    if let endIdx = cleanTitle.firstIndex(of: ")") {
                        cleanTitle = String(cleanTitle[cleanTitle.index(after: endIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                self.lastActiveUrl = urlString
                let parsedCurrent = Self.parseTimeString(rawCurr)
                let parsedDuration = Self.parseTimeString(rawDur)
                
                self.isPlaying = isVideoPlaying
                self.title = cleanTitle.isEmpty ? (isYT ? "YouTube Video" : "Web Video / Film") : cleanTitle
                self.artist = isYT ? "YouTube (\(browserName))" : "Film / Dizi (\(browserName))"
                self.album = "Web Medya"
                self.activePlayerName = isYT ? "YouTube" : "Chrome"
                self.duration = parsedDuration
                self.basePosition = parsedCurrent
                self.lastTimestamp = Date()
                self.playbackRate = isVideoPlaying ? 1.0 : 0.0
                
                self.loadBrowserArtwork(urlString: urlString, isYT: isYT)
            } else if status == "info" && parts.count >= 3 {
                let urlString = parts[2]
                let isMedia = Self.isMediaUrl(urlString)
                let isYT = urlString.contains("youtube.com") || parts[1].contains("YouTube")
                let isNewMedia = (self.lastActiveUrl != urlString)
                self.lastActiveUrl = urlString
                
                if isMedia {
                    var cleanTitle = parts[1]
                        .replacingOccurrences(of: " - Google Chrome", with: "")
                        .replacingOccurrences(of: " - YouTube", with: "")
                        .replacingOccurrences(of: "YouTube - ", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let pipeIdx = cleanTitle.lastIndex(of: "|") {
                        cleanTitle = String(cleanTitle[..<pipeIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    var parsedCurrent: Double = 0
                    if let tRange = urlString.range(of: "t=") {
                        let tSub = urlString[tRange.upperBound...]
                        let tStr = String(tSub.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" }))
                        parsedCurrent = Self.parseUrlTime(tStr)
                    }
                    
                    if isYT, let vIdx = urlString.range(of: "v=") {
                        let idSubstring = urlString[vIdx.upperBound...]
                        let videoId = String(idSubstring.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" }))
                        if !videoId.isEmpty {
                            self.fetchYouTubeDuration(videoId: videoId)
                        }
                    }
                    
                    self.isPlaying = true
                    self.title = cleanTitle.isEmpty ? (isYT ? "YouTube Video" : "Web Video / Film") : cleanTitle
                    self.artist = isYT ? "YouTube (\(browserName))" : "Film / Dizi (\(browserName))"
                    self.album = "Web Medya"
                    self.activePlayerName = isYT ? "YouTube" : "Chrome"
                    self.playbackRate = 1.0
                    
                    if isNewMedia {
                        self.basePosition = parsedCurrent
                        self.lastTimestamp = Date()
                    } else if parsedCurrent > 0 && abs(parsedCurrent - self.currentPosition) > 10.0 {
                        self.basePosition = parsedCurrent
                        self.lastTimestamp = Date()
                    }
                    
                    self.loadBrowserArtwork(urlString: urlString, isYT: isYT)
                } else {
                    self.isPlaying = false
                    self.playbackRate = 0.0
                    self.title = "Müzik Çalmıyor"
                    self.artist = ""
                    self.artwork = nil
                    self.duration = 0.0
                    self.basePosition = 0.0
                    self.lastActiveUrl = ""
                    self.activePlayerName = ""
                }
            } else if self.activePlayerName == "Chrome" || self.activePlayerName == "YouTube" {
                self.isPlaying = false
                self.playbackRate = 0.0
                self.title = "Müzik Çalmıyor"
                self.artist = ""
                self.artwork = nil
                self.duration = 0.0
                self.basePosition = 0.0
                self.lastActiveUrl = ""
                self.activePlayerName = ""
            }
        }
    }
    
    private func fetchYouTubeDuration(videoId: String) {
        if let cached = youtubeDurationCache[videoId] {
            DispatchQueue.main.async {
                self.duration = cached
            }
            return
        }
        
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else { return }
            if let range = html.range(of: "\"lengthSeconds\":\"") {
                let sub = html[range.upperBound...]
                let numStr = String(sub.prefix(while: { $0.isNumber }))
                if let sec = Double(numStr), sec > 0 {
                    DispatchQueue.main.async {
                        self?.youtubeDurationCache[videoId] = sec
                        self?.duration = sec
                    }
                }
            }
        }.resume()
    }
    
    public static func isMediaUrl(_ urlString: String) -> Bool {
        let lower = urlString.lowercased()
        if lower == "https://www.youtube.com" || lower == "https://www.youtube.com/" || lower == "http://www.youtube.com" || lower == "http://www.youtube.com/" || lower.contains("youtube.com/feed") || lower.contains("youtube.com/@") || lower.contains("youtube.com/channel") || lower.contains("youtube.com/results") {
            return false
        }
        if lower.contains("youtube.com/watch") || lower.contains("youtube.com/shorts") || lower.contains("youtu.be/") || lower.contains("youtube.com/live") { return true }
        if lower.contains("netflix.com/watch") { return true }
        if lower.contains("myasiantv") && (lower.contains("/ep/") || lower.contains("/watch/")) { return true }
        if lower.contains("/video/") || lower.contains("/watch/") || lower.contains("/stream/") || lower.contains("/ep/") { return true }
        if lower.contains("vimeo.com/") || lower.contains("dailymotion.com/video") || lower.contains("twitch.tv/") { return true }
        if lower.contains("soundcloud.com/") || lower.contains("music.apple.com") || lower.contains("open.spotify.com") { return true }
        return false
    }
    
    public static func parseUrlTime(_ text: String) -> Double {
        var clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix("s") && !clean.contains("m") && !clean.contains("h") {
            clean.removeLast()
            return Double(clean) ?? 0.0
        }
        var total: Double = 0
        if let hRange = clean.range(of: "h") {
            let h = Double(clean[..<hRange.lowerBound]) ?? 0
            total += h * 3600
            clean = String(clean[hRange.upperBound...])
        }
        if let mRange = clean.range(of: "m") {
            let m = Double(clean[..<mRange.lowerBound]) ?? 0
            total += m * 60
            clean = String(clean[mRange.upperBound...])
        }
        if clean.hasSuffix("s") {
            clean.removeLast()
        }
        total += Double(clean) ?? 0
        return total
    }
    
    private func loadBrowserArtwork(urlString: String, isYT: Bool) {
        var foundThumb = false
        if isYT, let vIdx = urlString.range(of: "v=") {
            let idSubstring = urlString[vIdx.upperBound...]
            let videoId = String(idSubstring.prefix(while: { $0 != "&" && $0 != "#" && $0 != "?" }))
            if !videoId.isEmpty, let thumbUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg") {
                foundThumb = true
                self.downloadImage(from: thumbUrl, cacheKey: videoId)
            }
        }
        
        if !foundThumb, let encodedUrl = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let favUrlString = "https://t0.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=\(encodedUrl)&size=128"
            if let favUrl = URL(string: favUrlString) {
                self.downloadImage(from: favUrl, cacheKey: "fav_\(encodedUrl)")
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
        if isSpotify {
            let script = "tell application \"Spotify\" to playpause"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(script) { _ in }
            }
        } else if activePlayerName == "Music" {
            let script = "tell application \"Music\" to playpause"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(script) { _ in }
            }
        } else {
            let script = """
            tell application "Google Chrome"
                if it is running then
                    try
                        execute front window's active tab javascript "(() => { const btn = document.querySelector('.ytp-play-button'); if (btn) { btn.click(); return; } const v = document.querySelector('video.html5-main-video') || document.querySelector('video'); if (v) { if (v.paused) v.play(); else v.pause(); } })()"
                    end try
                end if
            end tell
            """
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAppleScript(script) { _ in }
            }
        }
        
        DispatchQueue.main.async {
            self.isPlaying.toggle()
            self.playbackRate = self.isPlaying ? 1.0 : 0.0
            self.lastTimestamp = Date()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshPlaybackState()
        }
    }
    
    public func skipForward10() {
        let script = """
        tell application "Google Chrome"
            if it is running then
                try
                    execute front window's active tab javascript "(() => { const v = document.querySelector('video.html5-main-video') || document.querySelector('video'); if (v) { v.currentTime = Math.min(v.duration || 999999, v.currentTime + 10); } })()"
                end try
            end if
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(script) { _ in }
        }
        DispatchQueue.main.async {
            self.basePosition = min(self.duration > 0 ? self.duration : 999999, self.currentPosition + 10)
            self.lastTimestamp = Date()
        }
    }
    
    public func skipBackward10() {
        let script = """
        tell application "Google Chrome"
            if it is running then
                try
                    execute front window's active tab javascript "(() => { const v = document.querySelector('video.html5-main-video') || document.querySelector('video'); if (v) { v.currentTime = Math.max(0, v.currentTime - 10); } })()"
                end try
            end if
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(script) { _ in }
        }
        DispatchQueue.main.async {
            self.basePosition = max(0, self.currentPosition - 10)
            self.lastTimestamp = Date()
        }
    }
    
    public func nextTrack() {
        if let sendCommand = sendCommandFn {
            // kMRNextTrack = 4
            _ = sendCommand(4, nil)
        }
        Self.postHardwareMediaKey(keyCode: 19) // NX_KEYTYPE_FAST
        
        if isSpotify {
            let script = "tell application \"Spotify\" to next track"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.executeAppleScript(script) { _ in } }
        } else if activePlayerName == "Music" {
            let script = "tell application \"Music\" to next track"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.executeAppleScript(script) { _ in } }
        } else {
            let script = """
            tell application "Google Chrome"
                if it is running then
                    try
                        execute front window's active tab javascript "(() => { const btn = document.querySelector('.ytp-next-button'); if (btn) btn.click(); else { const v = document.querySelector('video'); if (v) v.currentTime += 10; } })()"
                    end try
                end if
            end tell
            """
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.executeAppleScript(script) { _ in } }
        }
        
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
        
        if isSpotify {
            let script = "tell application \"Spotify\" to previous track"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.executeAppleScript(script) { _ in } }
        } else if activePlayerName == "Music" {
            let script = "tell application \"Music\" to previous track"
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.executeAppleScript(script) { _ in } }
        } else {
            let script = """
            tell application "Google Chrome"
                if it is running then
                    try
                        execute front window's active tab javascript "(() => { const btn = document.querySelector('.ytp-prev-button'); if (btn) btn.click(); else { const v = document.querySelector('video'); if (v) v.currentTime -= 10; } })()"
                    end try
                end if
            end tell
            """
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.executeAppleScript(script) { _ in } }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshPlaybackState()
        }
    }
    
    public func seek(to position: Double) {
        let pos = max(0, min(duration > 0 ? duration : 3600.0, position))
        self.currentPosition = pos
        self.basePosition = pos
        self.lastTimestamp = Date()
        
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
        } else {
            let script = """
            tell application "Google Chrome"
                if it is running then
                    try
                        execute front window's active tab javascript "(() => { const v = document.querySelector('video.html5-main-video') || document.querySelector('video'); if (v) v.currentTime = \(pos); })()"
                    end try
                end if
            end tell
            """
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
    
    public static func parseTimeString(_ text: String) -> Double {
        let clean = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = clean.components(separatedBy: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2]) ?? 0
            return h * 3600 + m * 60 + s
        } else if parts.count == 2 {
            let m = Double(parts[0]) ?? 0
            let s = Double(parts[1]) ?? 0
            return m * 60 + s
        }
        return parseNumeric(clean)
    }
    
    public static func parseNumeric(_ text: String) -> Double {
        let clean = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean) ?? 0.0
    }
    
    public static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let totalSecs = Int(seconds)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}
