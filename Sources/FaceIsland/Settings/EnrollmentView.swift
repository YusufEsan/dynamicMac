import SwiftUI

public struct EnrollmentView: View {
    @Bindable private var enrollment = FaceEnrollmentManager.shared
    @Bindable private var battery = BatteryManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header with Real Battery Badge
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Face ID Kurulumu")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Kilit açmak için yüzünüzü tanıtın")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: battery.batteryIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(battery.batteryColor)
                    Text("%\(battery.level)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(battery.batteryColor)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.top, 10)
            
            // Camera Viewfinder Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(enrollment.progress))
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .animation(.spring, value: enrollment.progress)
                
                if let image = enrollment.latestPreviewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 180, height: 180)
                    
                    Image(systemName: "faceid")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.8))
                }
                
                if enrollment.currentStep == .completed {
                    Circle()
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 180, height: 180)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Status and step prompt
            VStack(spacing: 8) {
                Text(enrollment.statusMessage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(height: 38)
                
                ProgressView(value: enrollment.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 220)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                if !enrollment.isEnrolling && enrollment.currentStep != .completed {
                    Button("Start Enrollment") {
                        enrollment.startEnrollment()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if enrollment.isEnrolling {
                    Button("Cancel") {
                        enrollment.cancelEnrollment()
                    }
                    .buttonStyle(.bordered)
                } else if enrollment.currentStep == .completed {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(width: 360, height: 440)
        .padding()
        .onDisappear {
            if enrollment.isEnrolling {
                enrollment.cancelEnrollment()
            }
        }
    }
}
