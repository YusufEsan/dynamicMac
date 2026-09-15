import SwiftUI

public struct AudioMixerModuleView: View {
    private var mixer = AudioMixerManager.shared
    
    public init() {}
    
    public var body: some View {
        @Bindable var mixer = mixer
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.cyan)
                
                Text("Uygulama Ses Mikseri")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Anlık Ayar")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 4)
            
            // Sliders Container
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    // 1. Ana Sistem Sesi (Master Volume)
                    volumeRow(
                        title: "Ana Sistem Sesi",
                        icon: mixer.isMasterMuted ? "speaker.slash.fill" : (mixer.masterVolume > 50 ? "speaker.wave.3.fill" : (mixer.masterVolume > 0 ? "speaker.wave.1.fill" : "speaker.fill")),
                        iconColor: mixer.isMasterMuted ? .red : .blue,
                        value: Binding(
                            get: { mixer.masterVolume },
                            set: { mixer.setMasterVolume($0) }
                        ),
                        isActive: true,
                        isMuted: mixer.isMasterMuted,
                        onMuteToggle: { mixer.toggleMasterMute() }
                    )
                    
                    // 2. Spotify Sesi
                    if mixer.isSpotifyRunning {
                        volumeRow(
                            title: "Spotify",
                            icon: "waveform",
                            iconColor: Color(red: 0.11, green: 0.84, blue: 0.38),
                            value: Binding(
                                get: { mixer.spotifyVolume },
                                set: { mixer.setSpotifyVolume($0) }
                            ),
                            isActive: true
                        )
                    }
                    
                    // 3. Chrome / Web Medya Sesi
                    if mixer.isChromeRunning {
                        volumeRow(
                            title: "Google Chrome (Web Medya)",
                            icon: "play.tv.fill",
                            iconColor: .red,
                            value: Binding(
                                get: { mixer.chromeVolume },
                                set: { mixer.setChromeVolume($0) }
                            ),
                            isActive: true
                        )
                    }
                    
                    // 4. Apple Music Sesi
                    if mixer.isMusicRunning {
                        volumeRow(
                            title: "Apple Music",
                            icon: "music.note",
                            iconColor: .pink,
                            value: Binding(
                                get: { mixer.musicVolume },
                                set: { mixer.setMusicVolume($0) }
                            ),
                            isActive: true
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 140)
        }
    }
    
    private func volumeRow(
        title: String,
        icon: String,
        iconColor: Color,
        value: Binding<Double>,
        isActive: Bool,
        isMuted: Bool = false,
        onMuteToggle: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 10) {
            // App / Source Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.20))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Name
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
            
            // Slider
            Slider(value: value, in: 0...100, step: 1)
                .tint(iconColor)
            
            // Percent Text
            Text("\(Int(value.wrappedValue))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 34, alignment: .trailing)
            
            // Optional Mute Button
            if let onMute = onMuteToggle {
                Button(action: onMute) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isMuted ? .red : .white.opacity(0.6))
                        .padding(5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }
}
