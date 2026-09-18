import SwiftUI

public struct CalendarModuleView: View {
    @Bindable private var calendarManager = CalendarManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 12) {
            // Calendar icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.85), Color.red.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 3) {
                if let next = calendarManager.nextEvent {
                    Text(next.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(next.formattedStartTime)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if !calendarManager.countdownString.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack(spacing: 3.5) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(calendarManager.countdownString)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("No Events Today")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("All clear for now")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action button
            if let next = calendarManager.nextEvent, let url = next.meetingURL {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text("Join")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
