import SwiftUI
import AppKit

public struct HotkeyRecorderView: View {
    @Binding public var hotkeyString: String
    @State private var isRecording = false
    
    public init(hotkeyString: Binding<String>) {
        self._hotkeyString = hotkeyString
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                isRecording.toggle()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                        .foregroundColor(isRecording ? .red : .blue)
                    
                    Text(isRecording ? "Press Shortcut..." : hotkeyString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isRecording ? Color.red.opacity(0.15) : Color.white.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.red : Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            if !isRecording {
                Button(action: {
                    hotkeyString = "⌥ Tab"
                }) {
                    Text("Reset")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
