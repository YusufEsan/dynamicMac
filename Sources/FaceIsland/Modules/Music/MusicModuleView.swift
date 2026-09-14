import SwiftUI

public struct MusicModuleView: View {
    @Bindable private var music = NowPlayingManager.shared
    @Bindable private var faceRecognition = FaceRecognitionManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 16) {
            // Large Album Cover with Apple Music Badge
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.85, green: 0.35, blue: 0.45),
                                    Color(red: 0.45, green: 0.20, blue: 0.65),
                                    Color(red: 0.15, green: 0.15, blue: 0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)
                        .shadow(color: Color.pink.opacity(0.35), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Red Apple Music / Spotify Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 3)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: 4)
            }
            
            // Track Info & Playback Controls
            VStack(alignment: .leading, spacing: 2) {
                Text(music.title.isEmpty || music.title == "No Media Playing" ? "Venus" : music.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(music.album.isEmpty ? "VENUS" : music.album)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                
                Text(music.artist.isEmpty ? "Zara Larsson" : music.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                // Playback Controls
                HStack(spacing: 14) {
                    Button(action: { music.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { music.togglePlayPause() }) {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { music.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right Side: Mirror / FaceID Quick Action Button
            Button(action: {
                if faceRecognition.isScanning {
                    faceRecognition.stopRecognition()
                } else {
                    faceRecognition.startRecognition()
                }
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(faceRecognition.isScanning ? Color.cyan : Color.white.opacity(0.15), lineWidth: 1.5)
                            )
                        
                        Image(systemName: faceRecognition.isScanning ? "viewfinder" : "web.camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(faceRecognition.isScanning ? .cyan : .white.opacity(0.85))
                    }
                    
                    Text(faceRecognition.isScanning ? "Scanning" : "Mirror")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
