import Foundation
import EventKit
import AppKit

public struct CalendarEventItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let meetingURL: URL?
    
    public var minutesUntilStart: Int {
        Int(startDate.timeIntervalSince(Date()) / 60.0)
    }
    
    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
}

@Observable
public final class CalendarManager {
    public static let shared = CalendarManager()
    
    public var upcomingEvents: [CalendarEventItem] = []
    public var nextEvent: CalendarEventItem? = nil
    public var countdownString: String = ""
    
    private let eventStore = EKEventStore()
    private var updateTimer: Timer?
    
    private init() {
        startTimer()
        Task {
            await fetchEvents()
        }
    }
    
    public func startTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchEvents()
            }
        }
    }
    
    public func fetchEvents() async {
        guard PermissionManager.shared.calendarGranted else { return }
        
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(86400)
        
        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-1800), end: endOfDay, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        
        var items: [CalendarEventItem] = []
        for event in ekEvents {
            var meetURL: URL? = nil
            if let url = event.url {
                meetURL = url
            } else if let notes = event.notes {
                meetURL = extractMeetingURL(from: notes)
            } else if let loc = event.location {
                meetURL = extractMeetingURL(from: loc)
            }
            
            items.append(CalendarEventItem(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                meetingURL: meetURL
            ))
        }
        
        await MainActor.run {
            self.upcomingEvents = items
            self.nextEvent = items.first
            self.updateCountdown()
        }
    }
    
    private func updateCountdown() {
        guard let next = nextEvent else {
            countdownString = "No upcoming events"
            return
        }
        
        let diff = next.startDate.timeIntervalSince(Date())
        if diff <= 0 {
            countdownString = "Happening now"
        } else if diff < 3600 {
            let mins = Int(diff / 60)
            countdownString = "in \(mins)m"
        } else {
            let hours = Int(diff / 3600)
            let mins = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            countdownString = "in \(hours)h \(mins)m"
        }
    }
    
    private func extractMeetingURL(from text: String) -> URL? {
        let patterns = [
            "https://[a-zA-Z0-9.-]*zoom.us/j/[0-9]+[?a-zA-Z0-9=&_-]*",
            "https://meet.google.com/[a-z]{3}-[a-z]{4}-[a-z]{3}",
            "https://teams.microsoft.com/l/meetup-join/[a-zA-Z0-9%._-]+"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range, in: text) {
                    return URL(string: String(text[range]))
                }
            }
        }
        return nil
    }
}
