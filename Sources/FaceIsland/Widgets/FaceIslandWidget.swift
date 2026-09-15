import WidgetKit
import SwiftUI

// MARK: - Widget Entry
public struct FaceIDWidgetEntry: TimelineEntry {
    public let date: Date
    public let isScanning: Bool
    public let isRecognized: Bool
    public let statusText: String
}

// MARK: - Timeline Provider
public struct FaceIDWidgetProvider: TimelineProvider {
    public typealias Entry = FaceIDWidgetEntry

    public func placeholder(in context: Context) -> FaceIDWidgetEntry {
        FaceIDWidgetEntry(date: Date(), isScanning: false, isRecognized: true, statusText: "Face ID Hazır")
    }

    public func getSnapshot(in context: Context, completion: @escaping (FaceIDWidgetEntry) -> Void) {
        let status = WidgetSharedState.shared.currentStatus()
        completion(FaceIDWidgetEntry(date: Date(), isScanning: status.isScanning, isRecognized: status.isRecognized, statusText: status.statusText))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<FaceIDWidgetEntry>) -> Void) {
        let status = WidgetSharedState.shared.currentStatus()
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: currentDate) ?? currentDate.addingTimeInterval(5)
        let entry = FaceIDWidgetEntry(date: currentDate, isScanning: status.isScanning, isRecognized: status.isRecognized, statusText: status.statusText)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Entry View
public struct FaceIslandWidgetEntryView: View {
    var entry: FaceIDWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    public var body: some View {
        switch family {
        case .systemSmall:
            desktopSmallView
        default:
            desktopMediumView
        }
    }

    // MARK: - 1. Desktop Small Widget
    private var desktopSmallView: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let angle = (phase * 180).truncatingRemainder(dividingBy: 360)

            ZStack {
                ContainerRelativeShape()
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.08))

                VStack(spacing: 12) {
                    ZStack {
                        // Ambient Outer Pulse Ring
                        Circle()
                            .stroke(
                                entry.isScanning ? Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.2) : Color.white.opacity(0.08),
                                lineWidth: 4
                            )
                            .frame(width: 64, height: 64)

                        if entry.isScanning {
                            // Laser Radar Sweep
                            Circle()
                                .trim(from: 0.0, to: 0.4)
                                .stroke(
                                    AngularGradient(
                                        colors: [Color.green.opacity(0.0), Color(red: 0.11, green: 0.84, blue: 0.38)],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(angle))

                            Image(systemName: "faceid")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                                .scaleEffect(0.9 + 0.15 * sin(phase * 4))
                        } else if entry.isRecognized {
                            Circle()
                                .fill(Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.2))
                                .frame(width: 64, height: 64)
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                        } else {
                            Image(systemName: "faceid")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    VStack(spacing: 3) {
                        Text("FaceIsland")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        Text(entry.isScanning ? "Taranıyor..." : (entry.isRecognized ? "Doğrulandı" : "Korumalı"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(entry.isScanning || entry.isRecognized ? Color(red: 0.11, green: 0.84, blue: 0.38) : .white.opacity(0.55))
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - 2. Desktop Medium Widget
    private var desktopMediumView: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let angle = (phase * 180).truncatingRemainder(dividingBy: 360)

            HStack(spacing: 16) {
                // Left dynamic icon capsule
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 90, height: 90)

                    if entry.isScanning {
                        Circle()
                            .trim(from: 0.0, to: 0.4)
                            .stroke(
                                AngularGradient(
                                    colors: [Color.green.opacity(0.0), Color(red: 0.11, green: 0.84, blue: 0.38)],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 54, height: 54)
                            .rotationEffect(.degrees(angle))

                        Image(systemName: "faceid")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                            .scaleEffect(0.9 + 0.15 * sin(phase * 4))
                    } else if entry.isRecognized {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.84, blue: 0.38))
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(entry.isScanning || entry.isRecognized ? Color(red: 0.11, green: 0.84, blue: 0.38) : Color.white.opacity(0.4))
                            .frame(width: 7, height: 7)
                        Text("Biyometrik Kilit Motoru")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    Text(entry.isScanning ? "Yüzünüz taranıyor..." : (entry.isRecognized ? "Kullanıcı doğrulandı, kilit açıldı." : "Face ID devrede."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)

                    Spacer()

                    HStack(spacing: 8) {
                        Label("Apple Vision AI", systemImage: "sparkles")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.vertical, 14)
                .padding(.trailing, 14)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        }
    }
}

// MARK: - Widget Definition
public struct FaceIslandWidget: Widget {
    public let kind: String = "FaceIslandWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FaceIDWidgetProvider()) { entry in
            FaceIslandWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.05, green: 0.06, blue: 0.08)
                }
        }
        .configurationDisplayName("FaceIsland Face ID")
        .description("Masaüstünde ve Bildirim Merkezinde Face ID tarama durumunu ve animasyonunu canlı gösterir.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}
