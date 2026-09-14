import SwiftUI

public struct IslandView: View {
    @Bindable private var provider = IslandContentProvider.shared
    @Bindable private var music = NowPlayingManager.shared
    @Bindable private var faceRecognition = FaceRecognitionManager.shared
    @Bindable private var calendarManager = CalendarManager.shared
    @Bindable private var settings = SettingsManager.shared
    @Bindable private var keychain = KeychainHelper.shared
    @Bindable private var battery = BatteryManager.shared
    private var permissions = PermissionManager.shared
    
    @State private var isHovering = false
    @State private var activeTopTab: String = "Nook"
    @State private var settingsSubTab: String = "FaceID"
    @State private var showEnrollmentSheet: Bool = false
    @State private var unlockPasswordInput: String = ""
    @State private var passwordSaveStatus: String = ""
    @State private var isEditingPassword: Bool = false
    
    // Animation States
    @State private var equalizerBars: [CGFloat] = [0.4, 0.9, 0.6, 0.8, 0.3]
    @State private var radarRotation: Double = 0
    @State private var pulseGlow: Bool = false
    
    public var isTopAttached: Bool
    
    public init(isTopAttached: Bool = true) {
        self.isTopAttached = isTopAttached
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Pitch Black Card Background with subtle frosted stroke & liquid glow (No top edge stroke)
                IslandSquircle(cornerRadius: isExpanded ? 24 : 16, isTopAttached: isTopAttached)
                    .fill(Color.black)
                    .overlay(
                        IslandSquircleBorder(cornerRadius: isExpanded ? 24 : 16, isTopAttached: isTopAttached)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isExpanded ? 0.32 : 0.20),
                                        Color.green.opacity(faceRecognition.isRecognized ? 0.85 : 0.0),
                                        Color.cyan.opacity(faceRecognition.isScanning ? 0.75 : 0.05),
                                        music.themeColor.opacity(music.isPlaying ? 0.40 : 0.0),
                                        Color.blue.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: faceRecognition.isRecognized || faceRecognition.isScanning ? 1.6 : 1.2
                            )
                    )
                    .shadow(
                        color: faceRecognition.isRecognized ? Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.60) : (faceRecognition.isScanning ? Color.cyan.opacity(0.45) : (music.isPlaying ? music.themeColor.opacity(0.30) : Color.black.opacity(0.85))),
                        radius: isExpanded ? 28 : (faceRecognition.isRecognized || faceRecognition.isScanning ? 18 : 10),
                        x: 0,
                        y: isExpanded ? 10 : 2
                    )
                
                // Ambient Radial Glow when Music is Playing or Face ID Recognized
                if isExpanded && music.isPlaying {
                    RadialGradient(
                        colors: [
                            music.themeColor.opacity(0.22),
                            music.isSpotify ? Color.cyan.opacity(0.08) : Color.purple.opacity(0.10),
                            Color.clear
                        ],
                        center: .leading,
                        startRadius: 10,
                        endRadius: 280
                    )
                    .clipShape(IslandSquircle(cornerRadius: 24, isTopAttached: isTopAttached))
                    .blur(radius: 6)
                } else if faceRecognition.isRecognized {
                    RadialGradient(
                        colors: [
                            Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 180
                    )
                    .clipShape(IslandSquircle(cornerRadius: 16, isTopAttached: isTopAttached))
                    .blur(radius: 4)
                }
                
                // Content with Smooth Spring Transitions
                if isExpanded {
                    nookDashboardView
                        .transition(.opacity)
                } else {
                    compactNotchView
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(AnimationConstants.islandMorphSpring) {
                                IslandContentProvider.shared.toggleExpand()
                            }
                        }
                }
            }
            .contentShape(Rectangle())
            .frame(
                width: islandWidth,
                height: islandHeight
            )
            .animation(AnimationConstants.islandMorphSpring, value: islandWidth)
            .animation(AnimationConstants.islandMorphSpring, value: islandHeight)
            .animation(AnimationConstants.islandMorphSpring, value: isExpanded)
            .animation(AnimationConstants.islandMorphSpring, value: faceRecognition.isScanning)
            .animation(AnimationConstants.islandMorphSpring, value: faceRecognition.isRecognized)
            .animation(.easeInOut(duration: 0.22), value: isHovering)
            .onHover { hovering in
                self.isHovering = hovering
            }
            
            if isTopAttached {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showEnrollmentSheet) {
            EnrollmentView()
        }
        .onAppear {
            startLiveEqualizer()
            startRadarAnimation()
        }
    }
    
    private var formattedUserName: String {
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty {
            let first = fullName.components(separatedBy: " ").first ?? fullName
            return first
        }
        let userName = NSUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return userName.isEmpty ? "Kullanıcı" : userName.capitalized
    }
    
    private var isFaceIDActive: Bool {
        ScreenLockMonitor.shared.isScreenLocked || faceRecognition.isScanning || faceRecognition.isRecognized || faceRecognition.currentState == .notRecognized
    }
    
    // MARK: - Compact Notch Idle Content
    private var compactNotchView: some View {
        HStack(spacing: 8) {
            // Left Dynamic Icon: Face ID gets absolute priority during scan/unlock
            if isFaceIDActive {
                if faceRecognition.isScanning {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.2))
                            .frame(width: 20, height: 20)
                        Image(systemName: "faceid")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                            .scaleEffect(pulseGlow ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseGlow)
                    }
                } else if faceRecognition.isRecognized {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.84, blue: 0.38))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    }
                } else if case .notRecognized = faceRecognition.currentState {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.25))
                            .frame(width: 20, height: 20)
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 20, height: 20)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            } else if music.isPlaying || (!music.title.isEmpty && music.title != "Müzik Çalmıyor") {
                if let art = music.artwork {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .shadow(color: music.themeColor.opacity(0.4), radius: 3)
                        
                        if music.isSpotify {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.11, green: 0.84, blue: 0.38))
                                    .frame(width: 8, height: 8)
                                SpotifyLogoShape(size: 5.5, iconColor: .black)
                            }
                            .offset(x: 2, y: 2)
                        }
                    }
                } else if music.isSpotify {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(Color(red: 0.11, green: 0.84, blue: 0.38))
                            .frame(width: 20, height: 20)
                            .shadow(color: Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.4), radius: 3)
                        
                        SpotifyLogoShape(size: 13, iconColor: .black)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Center Live Text
            HStack {
                Spacer(minLength: 0)
                if isFaceIDActive {
                    if faceRecognition.isScanning {
                        Text("Face ID ile Taranıyor...")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                    } else if faceRecognition.isRecognized {
                        Text("Hoş Geldiniz, Kilit Açıldı")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                    } else if case .notRecognized = faceRecognition.currentState {
                        Text("Yüz Tanınamadı")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    } else {
                        Text("Ekran Kilitli")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                } else if music.isPlaying || (!music.title.isEmpty && music.title != "Müzik Çalmıyor") {
                    HStack(spacing: 4) {
                        Text(music.title)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if !music.artist.isEmpty {
                            Text("• \(music.artist)")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("Merhaba, \(formattedUserName)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            
            // Right Status: Equalizer Bars / Face ID status / Retry button
            if isFaceIDActive {
                if faceRecognition.isScanning {
                    HStack(spacing: 6) {
                        Image(systemName: "faceid")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                            .scaleEffect(pulseGlow ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseGlow)
                    }
                } else if faceRecognition.isRecognized {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                    }
                } else if case .notRecognized = faceRecognition.currentState {
                    Button(action: {
                        FaceRecognitionManager.shared.startRecognition()
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .bold))
                            Text("Tekrar Tara")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.85))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else if music.isPlaying {
                animatedEqualizer(barCount: 4, height: 13)
            } else if calendarManager.nextEvent != nil {
                Text(calendarManager.countdownString)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, isTopAttached ? 6 : 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - Pixel-Perfect Dashboard with 3 Full Dedicated Tabs
    private var nookDashboardView: some View {
        VStack(spacing: 8) {
            // Top Bar: [🎵 Medya] [📅 Takvim] [🧰 Tepsi] ... [⚙️] [✖]
            HStack(spacing: 10) {
                // 3 Segmented Pill Buttons
                HStack(spacing: 7) {
                    // 1. Media Tab (Spotify / YouTube / Apple Music / Browser)
                    Button(action: {
                        withAnimation(AnimationConstants.quickInteractive) {
                            activeTopTab = "Music"
                        }
                    }) {
                        HStack(spacing: 4) {
                            if music.isSpotify {
                                SpotifyLogoShape(size: 10, iconColor: activeTopTab == "Music" ? .green : .white.opacity(0.6))
                            } else if music.isYouTube {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(activeTopTab == "Music" ? .red : .white.opacity(0.6))
                            } else {
                                Image(systemName: "play.tv.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(activeTopTab == "Music" ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.6))
                            }
                            Text("Medya")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(
                            activeTopTab == "Music" ?
                            LinearGradient(colors: music.isSpotify ? [Color.green.opacity(0.35), Color.mint.opacity(0.18)] : (music.isYouTube ? [Color.red.opacity(0.35), Color.orange.opacity(0.18)] : [Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.35), Color.mint.opacity(0.18)]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundColor(activeTopTab == "Music" ? .white : .white.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(activeTopTab == "Music" ? (music.isSpotify ? Color.green.opacity(0.5) : (music.isYouTube ? Color.red.opacity(0.5) : Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.5))) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 2. Calendar Tab
                    Button(action: {
                        withAnimation(AnimationConstants.quickInteractive) {
                            activeTopTab = "Calendar"
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(activeTopTab == "Calendar" ? .orange : .white.opacity(0.6))
                            Text("Takvim")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(
                            activeTopTab == "Calendar" ?
                            LinearGradient(colors: [Color.orange.opacity(0.35), Color.yellow.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundColor(activeTopTab == "Calendar" ? .white : .white.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(activeTopTab == "Calendar" ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 3. Tray / Clipboard Tab
                    Button(action: {
                        withAnimation(AnimationConstants.quickInteractive) {
                            activeTopTab = "Tray"
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 10))
                                .foregroundColor(activeTopTab == "Tray" ? .cyan : .white.opacity(0.6))
                            Text("Tepsi (Pano)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(
                            activeTopTab == "Tray" ?
                            LinearGradient(colors: [Color.blue.opacity(0.38), Color.cyan.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundColor(activeTopTab == "Tray" ? .white : .white.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(activeTopTab == "Tray" ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Settings Gear Button - Switches tab inside Dynamic Island
                Button(action: {
                    withAnimation(AnimationConstants.quickInteractive) {
                        if activeTopTab == "Settings" {
                            activeTopTab = "Music"
                        } else {
                            activeTopTab = "Settings"
                        }
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(activeTopTab == "Settings" ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.85))
                        .padding(7)
                        .background(activeTopTab == "Settings" ? Color.green.opacity(0.25) : Color.white.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(activeTopTab == "Settings" ? Color.green.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .help("İzinler ve Ayarlar")
                
                // Close Button
                Button(action: {
                    withAnimation(AnimationConstants.islandMorphSpring) {
                        provider.collapse()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.90))
                        .padding(7)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .help("Kapat")
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            
            // Middle Tab Content
            ZStack(alignment: .top) {
                if activeTopTab == "Music" || activeTopTab == "Nook" {
                    // Full-Width Music Player
                    musicPlayerSection
                        .padding(.horizontal, 28)
                        .padding(.bottom, 8)
                        .frame(height: 92)
                        .transition(.opacity)
                } else if activeTopTab == "Calendar" {
                    // Full-Width Calendar Dashboard
                    calendarDateStripSection
                        .padding(.horizontal, 28)
                        .padding(.bottom, 8)
                        .frame(height: 92)
                        .transition(.opacity)
                } else if activeTopTab == "Tray" {
                    // Tray Tab View (Pano Geçmişi)
                    ClipboardModuleView()
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)
                        .frame(height: 186)
                        .transition(.opacity)
                } else if activeTopTab == "Settings" {
                    // In-Island Permissions & Settings View
                    islandSettingsAndPermissionsView
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)
                        .frame(height: tabContentHeight)
                        .transition(.opacity)
                }
            }
            .frame(height: tabContentHeight)
        }
    }
    
    // MARK: - Full Width Music Player Section with HD Cover & Wide Scrubber
    private var musicPlayerSection: some View {
        HStack(spacing: 16) {
            // Album Art Box with Spotify / Apple Music Badge
            ZStack(alignment: .bottomTrailing) {
                if let art = music.artwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: music.themeColor.opacity(music.isPlaying ? 0.6 : 0.2), radius: music.isPlaying ? 10 : 4, x: 0, y: 3)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: music.isSpotify ? [
                                        Color(red: 0.11, green: 0.72, blue: 0.33),
                                        Color(red: 0.08, green: 0.40, blue: 0.25),
                                        Color(red: 0.05, green: 0.15, blue: 0.12)
                                    ] : [
                                        Color(red: 0.82, green: 0.40, blue: 0.48),
                                        Color(red: 0.45, green: 0.22, blue: 0.65),
                                        Color(red: 0.15, green: 0.18, blue: 0.35)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 68, height: 68)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
                
                // Official Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(music.isSpotify ? Color(red: 0.11, green: 0.84, blue: 0.38) : (music.isYouTube ? Color.red : Color(red: 0.11, green: 0.84, blue: 0.38)))
                        .frame(width: 18, height: 18)
                        .shadow(color: (music.isSpotify ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.red).opacity(0.55), radius: 3, x: 0, y: 1)
                    
                    if music.isSpotify {
                        SpotifyLogoShape(size: 11.5, iconColor: .black)
                    } else if music.isYouTube {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 2, y: 2)
            }
            
            // Track Info & Full Controls
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(music.title.isEmpty ? "Müzik Çalmıyor" : music.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            Text(music.artist.isEmpty ? music.appNameDisplay : music.artist)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                            
                            if !music.album.isEmpty {
                                Text("• \(music.album)")
                                    .font(.system(size: 10.5, weight: .regular))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Playback Controls
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(AnimationConstants.quickInteractive) {
                                music.previousTrack()
                            }
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(AnimationConstants.quickInteractive) {
                                music.togglePlayPause()
                            }
                        }) {
                            Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(AnimationConstants.quickInteractive) {
                                music.nextTrack()
                            }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 4)
                }
                
                // Wide Scrubber Timeline Bar
                HStack(spacing: 8) {
                    Text(music.formattedPosition)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: true, vertical: false)
                    
                    GeometryReader { geo in
                        let total = max(1.0, music.duration)
                        let progress = min(1.0, max(0.0, music.currentPosition / total))
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            music.themeColor,
                                            music.isSpotify ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.white
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * CGFloat(progress)), height: 4)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 9, height: 9)
                                .shadow(color: music.themeColor.opacity(0.9), radius: 3)
                                .offset(x: max(0, min(geo.size.width - 9, geo.size.width * CGFloat(progress) - 4.5)))
                        }
                        .frame(height: 12)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                                    music.seek(to: fraction * total)
                                }
                        )
                    }
                    .frame(height: 12)
                    
                    Text(music.duration > 0 ? music.formattedDuration : (music.isPlaying ? "Canlı" : "0:00"))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Full Width Calendar Section
    private var calendarDateStripSection: some View {
        let calendar = Calendar.current
        let today = Date()
        
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "tr_TR")
        monthFormatter.dateFormat = "MMMM"
        let currentMonth = monthFormatter.string(from: today).capitalized
        let currentDayNum = calendar.component(.day, from: today)
        
        let dayNamesTR = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        
        return HStack(alignment: .center, spacing: 20) {
            // Month Title & Year + Event Pill
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(currentMonth)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(String(format: "%d", calendar.component(.year, from: today)))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: calendarManager.nextEvent != nil ? "calendar.badge.clock" : "calendar")
                        .font(.system(size: 9))
                        .foregroundColor(calendarManager.nextEvent != nil ? .orange : .white.opacity(0.45))
                    
                    if let next = calendarManager.nextEvent {
                        Text("\(next.title) • \(calendarManager.countdownString)")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    } else {
                        Text("Bugün etkinlik yok")
                            .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .frame(width: 170, alignment: .leading)
            
            Spacer()
            
            // Full 7-Day Strip
            HStack(spacing: 8) {
                ForEach(-3...3, id: \.self) { offset in
                    if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                        let day = calendar.component(.day, from: date)
                        let isToday = (day == currentDayNum)
                        let weekdayIndex = max(0, min(6, (calendar.component(.weekday, from: date) + 5) % 7))
                        let name = dayNamesTR[weekdayIndex]
                        let isWeekend = (weekdayIndex == 5 || weekdayIndex == 6)
                        
                        VStack(spacing: 3) {
                            Text(name)
                                .font(.system(size: 9, weight: isToday ? .bold : .medium))
                                .foregroundColor(isToday ? .white : (isWeekend ? Color.red.opacity(0.85) : Color.white.opacity(0.5)))
                            
                            Text(String(format: "%02d", day))
                                .font(.system(size: 13, weight: isToday ? .black : .semibold, design: .monospaced))
                                .foregroundColor(isToday ? .white : (isWeekend ? Color.red.opacity(0.95) : Color.white.opacity(0.85)))
                        }
                        .frame(width: 36, height: 48)
                        .background(
                            isToday ?
                            LinearGradient(colors: [Color.blue, Color(red: 0.1, green: 0.45, blue: 0.95)], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(isToday ? Color.cyan.opacity(0.7) : Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: isToday ? Color.blue.opacity(0.4) : Color.clear, radius: 4, y: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views for Equalizer
    private func animatedEqualizer(barCount: Int, height: CGFloat) -> some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: music.isSpotify ? [Color(red: 0.11, green: 0.84, blue: 0.38), Color.mint, Color.cyan] : [Color.pink, Color.purple, Color.cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: 2.5,
                        height: max(3, height * (i < equalizerBars.count ? equalizerBars[i] : 0.5))
                    )
            }
        }
        .frame(height: height)
    }
    
    private func startLiveEqualizer() {
        Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
            if music.isPlaying {
                withAnimation(.easeInOut(duration: 0.18)) {
                    equalizerBars = (0..<5).map { _ in CGFloat.random(in: 0.25...1.0) }
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    equalizerBars = [0.2, 0.2, 0.2, 0.2, 0.2]
                }
            }
        }
    }
    
    private func startRadarAnimation() {
        pulseGlow = true
        withAnimation(AnimationConstants.continuousRotation) {
            radarRotation = 360
        }
    }
    
    private var isExpanded: Bool {
        if case .expanded = provider.expansionState { return true }
        return false
    }
    
    private var islandWidth: CGFloat {
        guard isExpanded else {
            if faceRecognition.isScanning {
                return 340
            } else if faceRecognition.isRecognized {
                return 360
            } else if case .notRecognized = faceRecognition.currentState {
                return 360
            }
            return 320
        }
        switch activeTopTab {
        case "Music", "Nook":
            return 540
        case "Calendar":
            return 570
        case "Tray":
            return 740
        case "Settings":
            return 660
        default:
            return 540
        }
    }
    
    private var tabContentHeight: CGFloat {
        switch activeTopTab {
        case "Tray":
            return 186
        case "Settings":
            switch settingsSubTab {
            case "Style":
                return 118
            case "Permissions":
                return 165
            default: // "FaceID"
                return 185
            }
        case "Calendar":
            return 92
        default: // "Music"
            return 92
        }
    }
    
    private var islandHeight: CGFloat {
        guard isExpanded else { return 35 }
        switch activeTopTab {
        case "Tray":
            return 240
        case "Settings":
            switch settingsSubTab {
            case "Style":
                return 178
            case "Permissions":
                return 222
            default: // "FaceID"
                return 242
            }
        case "Calendar":
            return 152
        default:
            return 146
        }
    }
    
    // MARK: - In-Island Settings & Face ID View
    private var islandSettingsAndPermissionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sub-Bar Segments: [🛡️ Face ID & Kilit Açma] [🏝️ Ada Görünümü] [⚙️ Sistem İzinleri]
            HStack(spacing: 7) {
                Button(action: {
                    withAnimation(AnimationConstants.quickInteractive) {
                        settingsSubTab = "FaceID"
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "faceid")
                            .font(.system(size: 11, weight: .bold))
                        Text("Face ID")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        settingsSubTab == "FaceID" ?
                        Color.green.opacity(0.24) :
                        Color.white.opacity(0.06)
                    )
                    .foregroundColor(settingsSubTab == "FaceID" ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(settingsSubTab == "FaceID" ? Color.green.opacity(0.55) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(AnimationConstants.quickInteractive) {
                        settingsSubTab = "Style"
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 11, weight: .bold))
                        Text("Ada Stili")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        settingsSubTab == "Style" ?
                        Color.green.opacity(0.24) :
                        Color.white.opacity(0.06)
                    )
                    .foregroundColor(settingsSubTab == "Style" ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(settingsSubTab == "Style" ? Color.green.opacity(0.55) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(AnimationConstants.quickInteractive) {
                        settingsSubTab = "Permissions"
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.badge.checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("İzinler")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        settingsSubTab == "Permissions" ?
                        Color.green.opacity(0.24) :
                        Color.white.opacity(0.06)
                    )
                    .foregroundColor(settingsSubTab == "Permissions" ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(settingsSubTab == "Permissions" ? Color.green.opacity(0.55) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if settingsSubTab == "Permissions" {
                    Button(action: {
                        permissions.checkAll()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Yenile")
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 26)
            
            // Sub-Panel Content
            ZStack(alignment: .topLeading) {
                if settingsSubTab == "FaceID" {
                    faceIDSettingsPanel
                } else if settingsSubTab == "Style" {
                    islandStylePanel
                } else {
                    permissionsSettingsPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Island Style Dedicated In-Island Panel
    private var islandStylePanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Option 1: Çentik Modu (Üste Yapışık)
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        settings.forceFloatingCapsule = false
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .stroke(!settings.forceFloatingCapsule ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.45), lineWidth: 1.2)
                                    .frame(width: 22, height: 14)
                                
                                // Notch attached to top
                                Capsule()
                                    .fill(!settings.forceFloatingCapsule ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.55))
                                    .frame(width: 8, height: 3.5)
                            }
                            .frame(width: 22, height: 14)
                            
                            Spacer()
                            
                            if !settings.forceFloatingCapsule {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                            }
                        }
                        
                        Text("Çentik Adası (Ada)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(!settings.forceFloatingCapsule ? .white : .white.opacity(0.75))
                        
                        Text("Üste yapışık çentik adası")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                    .background(!settings.forceFloatingCapsule ? Color.green.opacity(0.20) : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(!settings.forceFloatingCapsule ? Color.green.opacity(0.65) : Color.white.opacity(0.10), lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)
                
                // Option 2: Yüzen Kapsül (Ayrı)
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        settings.forceFloatingCapsule = true
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .stroke(settings.forceFloatingCapsule ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.45), lineWidth: 1.2)
                                    .frame(width: 22, height: 14)
                                
                                // Detached floating capsule
                                Capsule()
                                    .fill(settings.forceFloatingCapsule ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.55))
                                    .frame(width: 9, height: 3.8)
                            }
                            .frame(width: 22, height: 14)
                            
                            Spacer()
                            
                            if settings.forceFloatingCapsule {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                            }
                        }
                        
                        Text("Yüzen Kapsül (Ayrı)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(settings.forceFloatingCapsule ? .white : .white.opacity(0.75))
                        
                        Text("Serbestçe taşınabilir ayrı ada")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                    .background(settings.forceFloatingCapsule ? Color.green.opacity(0.20) : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(settings.forceFloatingCapsule ? Color.green.opacity(0.65) : Color.white.opacity(0.10), lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Face ID Dedicated In-Island Panel
    private var faceIDSettingsPanel: some View {
        VStack(spacing: 7) {
            // Row 1: Profile Status Card & Quick Actions (Full Width)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(faceRecognition.isEnrolled ? Color.green.opacity(0.18) : Color.white.opacity(0.10))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: faceRecognition.isEnrolled ? "checkmark.circle.fill" : "faceid")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(faceRecognition.isEnrolled ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.85))
                }
                
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(faceRecognition.isEnrolled ? "Face ID Profili Aktif" : "Face ID Kaydı Bulunmuyor")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(faceRecognition.isEnrolled ? "Kamera ile kilit açma devrede" : "Oturum açmak için yüzünüzü tanıtın")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 7) {
                    // Yeniden Eğit Button - Matching Frosted Glass Capsule
                    Button(action: {
                        showEnrollmentSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9.5))
                            Text(faceRecognition.isEnrolled ? "Yeniden Eğit" : "Yüzü Tanıt")
                        }
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    if faceRecognition.isEnrolled {
                        // Şimdi Tara Button - Matching Frosted Glass Capsule
                        Button(action: {
                            FaceRecognitionManager.shared.startRecognition()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 9.5))
                                Text("Şimdi Tara")
                            }
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6.5)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(faceRecognition.isEnrolled ? Color.green.opacity(0.25) : Color.white.opacity(0.10), lineWidth: 1)
            )
            
            // Row 2: Auto-Unlock Switch & Mac Password Vault Authorization (Full Width Grid)
            HStack(spacing: 8) {
                // Left: Oto-Kilit Aç Switch Card
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        settings.autoUnlockEnabled.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 11))
                            .foregroundColor(settings.autoUnlockEnabled ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .background(settings.autoUnlockEnabled ? Color.green.opacity(0.20) : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Oto-Kilit Aç")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                            Text(settings.autoUnlockEnabled ? "Devrede (İzin Verildi)" : "Kapalı (Devre Dışı)")
                                .font(.system(size: 9.5))
                                .foregroundColor(settings.autoUnlockEnabled ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.45))
                        }
                        
                        Spacer(minLength: 4)
                        
                        ZStack(alignment: settings.autoUnlockEnabled ? .trailing : .leading) {
                            Capsule()
                                .fill(settings.autoUnlockEnabled ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.white.opacity(0.20))
                                .frame(width: 30, height: 17)
                                .shadow(color: settings.autoUnlockEnabled ? Color.green.opacity(0.5) : Color.clear, radius: 3)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 13, height: 13)
                                .padding(2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(settings.autoUnlockEnabled ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Right: Mac Şifresi & İzin / Yetki Korumalı Kasa Card
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11))
                        .foregroundColor(keychain.hasSavedPassword ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background((keychain.hasSavedPassword ? Color.green : Color.white).opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    
                    if keychain.hasSavedPassword && !isEditingPassword {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Mac Şifresi & İzni")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Yetkilendirildi (AES-256)")
                                .font(.system(size: 9.5))
                                .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                        }
                        
                        Spacer(minLength: 4)
                        
                        Button(action: {
                            isEditingPassword = true
                        }) {
                            Text("Değiştir")
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                keychain.deletePassword()
                                passwordSaveStatus = "Silindi"
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 9.5))
                                .foregroundColor(.red.opacity(0.9))
                                .padding(5)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            SecureField("Mac Şifreniz", text: $unlockPasswordInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.20), lineWidth: 1))
                                .onSubmit {
                                    savePasswordAction()
                                }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Yetki Ver & Kaydet - Frosted Glass Button matching "Şimdi Tara"
                        Button(action: {
                            savePasswordAction()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                                Text("Kaydet")
                            }
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        
                        if isEditingPassword {
                            Button(action: { isEditingPassword = false }) {
                                Text("İptal")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(keychain.hasSavedPassword ? Color.green.opacity(0.25) : Color.white.opacity(0.10), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)
            
            // Row 3: Custom Luxury Sensitivity Slider Card (Full Width with Green Accent)
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                
                Text("Eşleşme Hassasiyeti")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: 120, alignment: .leading)
                
                // Custom Gradient Glassmorphic Slider (Green Emerald Gradient)
                CustomSensitivitySlider(value: $settings.faceIDThreshold)
                    .frame(maxWidth: .infinity)
                
                HStack(spacing: 2) {
                    Text("%\(Int(settings.faceIDThreshold * 100))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                    
                    if abs(settings.faceIDThreshold - 0.78) < 0.01 {
                        Text("(İdeal)")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                    }
                }
                .frame(width: 55, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Permissions In-Island Panel
    private var permissionsSettingsPanel: some View {
        VStack(spacing: 7) {
            // Permissions 2x2 Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                inIslandPermissionCard(
                    title: "Kamera (Face ID)",
                    icon: "camera.fill",
                    isGranted: permissions.cameraGranted,
                    onGrant: { Task { _ = await permissions.requestCameraAccess() } },
                    onOpen: { permissions.openSettings(for: .camera) }
                )
                
                inIslandPermissionCard(
                    title: "Erişilebilirlik (⌥ Tab)",
                    icon: "hand.raised.fill",
                    isGranted: permissions.accessibilityGranted,
                    onGrant: { permissions.requestAccessibility() },
                    onOpen: { permissions.openSettings(for: .accessibility) }
                )
                
                inIslandPermissionCard(
                    title: "Ekran Kaydı (Önizleme)",
                    icon: "display",
                    isGranted: permissions.screenRecordingGranted,
                    onGrant: { permissions.requestScreenRecording() },
                    onOpen: { permissions.openSettings(for: .screenRecording) }
                )
                
                inIslandPermissionCard(
                    title: "Takvim (Etkinlikler)",
                    icon: "calendar",
                    isGranted: permissions.calendarGranted,
                    onGrant: { Task { _ = await permissions.requestCalendarAccess() } },
                    onOpen: { permissions.openSettings(for: .calendar) }
                )
            }
            
            // Bottom Action: Launch at Login
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    settings.launchAtLogin.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundColor(settings.launchAtLogin ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(settings.launchAtLogin ? Color.green.opacity(0.20) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    
                    Text("Başlangıçta Aç")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.leading, 4)
                    
                    Spacer()
                    
                    // Custom Apple-style Green Switch Capsule
                    ZStack(alignment: settings.launchAtLogin ? .trailing : .leading) {
                        Capsule()
                            .fill(settings.launchAtLogin ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.white.opacity(0.20))
                            .frame(width: 32, height: 18)
                            .shadow(color: settings.launchAtLogin ? Color.green.opacity(0.55) : Color.clear, radius: 4)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .padding(2)
                            .shadow(color: Color.black.opacity(0.35), radius: 2)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(settings.launchAtLogin ? Color.green.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    
    private func inIslandPermissionCard(
        title: String,
        icon: String,
        isGranted: Bool,
        onGrant: @escaping () -> Void,
        onOpen: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 22, height: 22)
                .background((isGranted ? Color.green : Color.orange).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Spacer(minLength: 2)
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.green)
            } else {
                HStack(spacing: 5) {
                    Button(action: onGrant) {
                        Text("İzin Ver")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onOpen) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(4)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Sistem Ayarlarını Aç")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func savePasswordAction() {
        let trimmed = unlockPasswordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        keychain.savePassword(trimmed)
        unlockPasswordInput = ""
        isEditingPassword = false
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            passwordSaveStatus = "Kaydedildi"
        }
    }
}

// MARK: - Custom Glassmorphic Gradient Sensitivity Slider
public struct CustomSensitivitySlider: View {
    @Binding var value: Double
    private let range: ClosedRange<Double> = 0.60...0.95
    
    public init(value: Binding<Double>) {
        self._value = value
    }
    
    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = CGFloat(max(0.0, min(1.0, (value - range.lowerBound) / (range.upperBound - range.lowerBound))))
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 6)
                
                // Active Gradient Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.55), Color(red: 0.11, green: 0.84, blue: 0.38)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, width * fraction), height: 6)
                
                // Custom Glowing Thumb Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().stroke(Color(red: 0.11, green: 0.84, blue: 0.38), lineWidth: 2))
                    .shadow(color: Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.7), radius: 4)
                    .offset(x: max(0, min(width - 15, width * fraction - 7.5)))
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newFraction = max(0.0, min(1.0, gesture.location.x / width))
                        let newValue = range.lowerBound + Double(newFraction) * (range.upperBound - range.lowerBound)
                        value = (newValue * 100).rounded() / 100.0
                    }
            )
        }
        .frame(height: 18)
    }
}
