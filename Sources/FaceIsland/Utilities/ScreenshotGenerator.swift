import SwiftUI
import AppKit

public struct ScreenshotGenerator {
    @MainActor
    public static func generateAll() {
        print("📸 Generating screenshots from real IslandView components...")
        
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        let outputDir = URL(fileURLWithPath: currentPath).appendingPathComponent("assets/screenshots")
        
        try? fileManager.removeItem(at: outputDir)
        try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let wallpaperPath = "/System/Library/Desktop Pictures/Sonoma.heic"
        let wallpaperImage = NSImage(contentsOfFile: wallpaperPath)
        
        // Base seed permissions
        PermissionManager.shared.cameraGranted = true
        PermissionManager.shared.accessibilityGranted = true
        PermissionManager.shared.calendarGranted = true
        PermissionManager.shared.screenRecordingGranted = true
        AudioMixerManager.shared.isMockMode = true
        ClipboardManager.shared.isMockMode = true
        
        let configs: [(name: String, width: CGFloat, height: CGFloat, isFloating: Bool, setup: () -> AnyView)] = [
            ("01_music_player.png", 680, 200, false, {
                NowPlayingManager.shared.title = "Starboy"
                NowPlayingManager.shared.artist = "The Weeknd, Daft Punk"
                NowPlayingManager.shared.album = "Starboy"
                NowPlayingManager.shared.isPlaying = true
                NowPlayingManager.shared.duration = 230.0
                NowPlayingManager.shared.currentPosition = 98.0
                NowPlayingManager.shared.activePlayerName = "Spotify"
                NowPlayingManager.shared.lastActiveUrl = ""
                SettingsManager.shared.enableNotchVideoPlayer = false
                IslandContentProvider.shared.expansionState = .expanded(.music)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Music").id("music_player"))
            }),
            ("02_calendar.png", 700, 185, false, {
                CalendarManager.shared.nextEvent = CalendarEventItem(
                    id: "1",
                    title: "Sprint Değerlendirme & Tasarım",
                    startDate: Date().addingTimeInterval(9540),
                    endDate: Date().addingTimeInterval(13140),
                    isAllDay: false,
                    location: nil,
                    meetingURL: nil
                )
                CalendarManager.shared.upcomingEvents = [
                    CalendarEventItem(
                        id: "1",
                        title: "Sprint Değerlendirme & Tasarım",
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(3600),
                        isAllDay: false,
                        location: nil,
                        meetingURL: nil
                    )
                ]
                CalendarManager.shared.countdownString = "2 sa 39 dk sonra"
                IslandContentProvider.shared.expansionState = .expanded(.calendar)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Calendar").id("calendar_view"))
            }),
            ("03_clipboard_manager.png", 840, 320, false, {
                ClipboardManager.shared.items = [
                    ClipboardItem(text: "git push origin main", timestamp: Date().addingTimeInterval(-120), source: .mac, isPinned: true),
                    ClipboardItem(text: "https://github.com/YusufEsan/dynamicMac", timestamp: Date().addingTimeInterval(-720), source: .phone, isPinned: false),
                    ClipboardItem(text: "guard let event = nextEvent else { return }", timestamp: Date().addingTimeInterval(-1800), source: .mac, isPinned: false),
                    ClipboardItem(text: "npm run build && swift run FaceIsland", timestamp: Date().addingTimeInterval(-3600), source: .mac, isPinned: false),
                    ClipboardItem(text: "Meeting ID: 894 2314 9901", timestamp: Date().addingTimeInterval(-7200), source: .phone, isPinned: false),
                    ClipboardItem(text: "02_audio_mixer, 03_clipboard_manager", timestamp: Date().addingTimeInterval(-14400), source: .mac, isPinned: false)
                ]
                IslandContentProvider.shared.expansionState = .expanded(.clipboard)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Tray").id("clipboard_manager"))
            }),
            ("04_audio_mixer.png", 750, 320, false, {
                AudioMixerManager.shared.masterVolume = 80.0
                AudioMixerManager.shared.isMasterMuted = false
                AudioMixerManager.shared.activeApps = [
                    AudioAppInfo(id: "chrome", bundleId: "com.google.Chrome", name: "Google Chrome", icon: "play.tv.fill", iconColor: Color(red: 0.95, green: 0.35, blue: 0.35), volume: 85.0),
                    AudioAppInfo(id: "spotify", bundleId: "com.spotify.client", name: "Spotify", icon: "waveform", iconColor: Color(red: 0.11, green: 0.84, blue: 0.38), volume: 65.0),
                    AudioAppInfo(id: "safari", bundleId: "com.apple.Safari", name: "Safari", icon: "safari.fill", iconColor: Color(red: 0.20, green: 0.65, blue: 1.0), volume: 90.0),
                    AudioAppInfo(id: "quicktime", bundleId: "com.apple.QuickTimePlayerX", name: "QuickTime Player", icon: "play.rectangle.fill", iconColor: Color(red: 0.20, green: 0.70, blue: 0.90), volume: 45.0)
                ]
                IslandContentProvider.shared.expansionState = .expanded(.audio)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Audio").id("audio_mixer"))
            }),
            ("05_settings_faceid.png", 790, 325, false, {
                IslandContentProvider.shared.expansionState = .expanded(.faceID)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Settings", initialSettingsSubTab: "FaceID").id("settings_faceid"))
            }),
            ("06_settings_style.png", 790, 360, false, {
                SettingsManager.shared.enableNotchVideoPlayer = true
                IslandContentProvider.shared.expansionState = .expanded(.faceID)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Settings", initialSettingsSubTab: "Style").id("settings_style"))
            }),
            ("07_settings_permissions.png", 790, 255, false, {
                IslandContentProvider.shared.expansionState = .expanded(.faceID)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Settings", initialSettingsSubTab: "Permissions").id("settings_permissions"))
            }),
            ("08_compact_notch.png", 500, 110, false, {
                NowPlayingManager.shared.isPlaying = false
                CalendarManager.shared.nextEvent = CalendarEventItem(
                    id: "1",
                    title: "Sprint Değerlendirme & Tasarım",
                    startDate: Date().addingTimeInterval(9540),
                    endDate: Date().addingTimeInterval(13140),
                    isAllDay: false,
                    location: nil,
                    meetingURL: nil
                )
                CalendarManager.shared.countdownString = "2 sa 39 dk sonra"
                IslandContentProvider.shared.expansionState = .compact
                return AnyView(IslandView(isTopAttached: true, initialTab: "Nook").id("compact_notch"))
            }),
            ("09_notch_video_player.png", 650, 430, false, {
                NowPlayingManager.shared.title = "Apple Keynote: macOS Sequoia & Apple Intelligence"
                NowPlayingManager.shared.artist = "YouTube"
                NowPlayingManager.shared.isPlaying = true
                NowPlayingManager.shared.duration = 645.0
                NowPlayingManager.shared.currentPosition = 214.0
                NowPlayingManager.shared.activePlayerName = "Chrome"
                NowPlayingManager.shared.lastActiveUrl = "https://www.youtube.com/watch?v=apple-keynote"
                SettingsManager.shared.enableNotchVideoPlayer = true
                IslandContentProvider.shared.expansionState = .expanded(.music)
                return AnyView(IslandView(isTopAttached: true, initialTab: "Music").id("notch_video_player"))
            }),
            ("10_floating_capsule.png", 520, 140, true, {
                SettingsManager.shared.enableNotchVideoPlayer = false
                NowPlayingManager.shared.isPlaying = true
                NowPlayingManager.shared.title = "Blinding Lights"
                NowPlayingManager.shared.artist = "The Weeknd"
                NowPlayingManager.shared.album = "After Hours"
                NowPlayingManager.shared.activePlayerName = "Spotify"
                NowPlayingManager.shared.lastActiveUrl = ""
                CalendarManager.shared.nextEvent = nil
                IslandContentProvider.shared.expansionState = .compact
                return AnyView(IslandView(isTopAttached: false, initialTab: "Music").id("floating_capsule"))
            })
        ]
        
        for config in configs {
            let outputUrl = outputDir.appendingPathComponent(config.name)
            let view = config.setup()
            
            let fullView = createMockupWrapper(
                wallpaper: wallpaperImage,
                width: config.width,
                height: config.height,
                isFloating: config.isFloating
            ) {
                view
            }
            
            let renderer = ImageRenderer(content: fullView)
            renderer.scale = 2.0
            
            if let image = renderer.nsImage,
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: outputUrl)
                print("  ✅ Saved \(config.name) (\(Int(config.width * 2))x\(Int(config.height * 2)))")
            } else {
                print("  ❌ Failed to render \(config.name)")
            }
        }
        
        print("🎉 All 10 distinct screenshots generated successfully!")
    }
    
    @MainActor
    private static func createMockupWrapper<Content: View>(
        wallpaper: NSImage?,
        width: CGFloat,
        height: CGFloat,
        isFloating: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: isFloating ? .center : .top) {
            // Wallpaper Background
            if let wallpaper = wallpaper {
                Image(nsImage: wallpaper)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.22),
                        Color(red: 0.15, green: 0.25, blue: 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: width, height: height)
            }
            
            // Subtle dark vignette to make the island pop
            LinearGradient(
                colors: [Color.black.opacity(0.35), Color.black.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)
            
            // Real Island View Container
            VStack(spacing: 0) {
                content()
                    .padding(.top, isFloating ? 0 : 0)
                
                if !isFloating {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}
