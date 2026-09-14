import SwiftUI

public struct AudioControlModuleView: View {
    @Bindable private var audioManager = AppAudioManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            if audioManager.activeApps.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No audio-producing apps active")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(audioManager.activeApps) { app in
                            HStack(spacing: 10) {
                                // App Icon
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                } else {
                                    Image(systemName: "app.dashed")
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                // App Name
                                Text(app.name)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 80, alignment: .leading)
                                    .lineLimit(1)
                                
                                // Mute Button
                                Button(action: { audioManager.toggleMute(for: app) }) {
                                    Image(systemName: app.isMuted ? "speaker.slash.fill" : (app.volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                                        .font(.system(size: 11))
                                        .foregroundColor(app.isMuted ? .red : .white.opacity(0.7))
                                        .frame(width: 20)
                                }
                                .buttonStyle(.plain)
                                
                                // Volume Slider
                                Slider(
                                    value: Binding(
                                        get: { Double(app.volume) },
                                        set: { audioManager.setVolume(for: app, volume: Float($0)) }
                                    ),
                                    in: 0...1
                                )
                                .accentColor(.cyan)
                                
                                // Percentage Label
                                Text("\(Int(app.volume * 100))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 32, alignment: .trailing)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(.vertical, 6)
    }
}
