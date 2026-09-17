import SwiftUI

public struct AudioMixerModuleView: View {
    private var mixer = AudioMixerManager.shared
    
    public init() {}
    
    public var body: some View {
        @Bindable var mixer = mixer
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                
                Text("Uygulama Ses Mikseri")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(mixer.activeAppCount) Kaynak")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 4)
            
            // Sliders Container (Scrollable after 5 rows)
            ScrollView(.vertical, showsIndicators: mixer.activeAppCount > 5) {
                VStack(spacing: 6) {
                    // 1. Ana Sistem Sesi (Master Volume) - Always present
                    volumeRow(
                        title: "Ana Sistem Sesi",
                        icon: mixer.isMasterMuted ? "speaker.slash.fill" : (mixer.masterVolume > 50 ? "speaker.wave.3.fill" : (mixer.masterVolume > 0 ? "speaker.wave.1.fill" : "speaker.fill")),
                        iconColor: mixer.isMasterMuted ? .gray : Color(red: 0.11, green: 0.84, blue: 0.38),
                        value: Binding(
                            get: { mixer.masterVolume },
                            set: { mixer.setMasterVolume($0) }
                        ),
                        isActive: true,
                        isMuted: mixer.isMasterMuted,
                        onMuteToggle: { mixer.toggleMasterMute() }
                    )
                    
                    // 2. Dynamically Detected Active Apps
                    ForEach(mixer.activeApps) { app in
                        volumeRow(
                            title: app.name,
                            icon: app.icon,
                            iconColor: app.isMuted ? .gray : app.iconColor,
                            value: Binding(
                                get: { app.volume },
                                set: { mixer.setAppVolume(id: app.id, volume: $0) }
                            ),
                            isActive: true,
                            isMuted: app.isMuted || app.volume == 0,
                            onMuteToggle: { mixer.toggleAppMute(id: app.id) }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
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
            
            // Custom Colored Slider
            GeometryReader { geo in
                let val = CGFloat(value.wrappedValue) / 100.0
                let progress = max(0, min(1, val))
                let width = geo.size.width
                
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)
                    
                    // Filled colored progress
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.8), iconColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, width * progress), height: 5)
                        .shadow(color: iconColor.opacity(0.4), radius: 3)
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: iconColor.opacity(0.6), radius: 3)
                        .offset(x: max(0, min(width - 12, (width * progress) - 6)))
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let ratio = max(0, min(1, gesture.location.x / width))
                            value.wrappedValue = Double(ratio * 100.0)
                        }
                )
            }
            .frame(height: 18)
            
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
        .padding(.vertical, 4.5)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

