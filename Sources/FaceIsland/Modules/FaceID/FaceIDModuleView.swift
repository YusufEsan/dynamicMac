import SwiftUI

public struct FaceIDModuleView: View {
    @Bindable private var faceRecognition = FaceRecognitionManager.shared
    @State private var isPulsing = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 14) {
            // Face ID Scanner Icon / Radar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.15 : 0.95)
                    .animation(faceRecognition.isScanning ? AnimationConstants.radarPulse : .default, value: isPulsing)
                
                Image(systemName: iconNameForState())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colorForState())
            }
            .onAppear {
                isPulsing = true
            }
            
            // Status and confidence
            VStack(alignment: .leading, spacing: 3) {
                Text(titleForState())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if faceRecognition.isEnrolled {
                    Text(subtitleForState())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("No face enrolled. Open Settings to enroll.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action button
            if faceRecognition.isEnrolled {
                Button(action: {
                    if faceRecognition.isScanning {
                        faceRecognition.stopRecognition()
                    } else {
                        faceRecognition.startRecognition()
                    }
                }) {
                    Text(faceRecognition.isScanning ? "Cancel" : "Scan Face")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(faceRecognition.isScanning ? Color.red.opacity(0.8) : Color.blue.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    private func iconNameForState() -> String {
        switch faceRecognition.currentState {
        case .idle:
            return "faceid"
        case .scanning:
            return "viewfinder"
        case .recognized:
            return "checkmark.circle.fill"
        case .notRecognized, .noFaceDetected, .cameraUnavailable:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func colorForState() -> Color {
        switch faceRecognition.currentState {
        case .idle:
            return .blue
        case .scanning:
            return .cyan
        case .recognized:
            return .green
        case .notRecognized, .noFaceDetected, .cameraUnavailable:
            return .red
        }
    }
    
    private func titleForState() -> String {
        switch faceRecognition.currentState {
        case .idle:
            return "Face ID Ready"
        case .scanning:
            return "Scanning Face..."
        case .recognized:
            return "Unlocked with Face ID"
        case .notRecognized:
            return "Face Not Recognized"
        case .noFaceDetected:
            return "No Face Detected"
        case .cameraUnavailable:
            return "Camera Unavailable"
        }
    }
    
    private func subtitleForState() -> String {
        switch faceRecognition.currentState {
        case .idle:
            return "Face Unlock & Security Active"
        case .scanning(let progress):
            return "Matching features \(Int(progress * 100))%"
        case .recognized(let conf):
            return "Confidence: \(Int(conf * 100))%"
        case .notRecognized:
            return "Try looking directly at camera"
        case .noFaceDetected:
            return "Ensure good lighting"
        case .cameraUnavailable:
            return "Check camera permissions"
        }
    }
}
