import Foundation
import EventKit
import AppKit

public struct CalendarEventItem: Identifiable, Equatable, Sendable {
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
        
        // Listen to macOS EventKit real-time change notifications (new event, edits, iCloud sync)
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            self?.eventStore.refreshSourcesIfNecessary()
            Task {
                await self?.fetchEvents()
            }
        }
        
        // Listen to app activation / window focus
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.eventStore.refreshSourcesIfNecessary()
            Task {
                await self?.fetchEvents()
            }
        }
        
        Task {
            await fetchEvents()
        }
    }
    
    public func startTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchEvents()
            }
        }
    }
    
    public func fetchEvents() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            _ = await PermissionManager.shared.requestCalendarAccess()
        } else {
            PermissionManager.shared.checkCalendar()
        }
        
        let verifiedStatus = EKEventStore.authorizationStatus(for: .event)
        let isAuthorized = (verifiedStatus == .fullAccess || verifiedStatus == .writeOnly || verifiedStatus == .authorized || !eventStore.calendars(for: .event).isEmpty)
        
        guard isAuthorized else {
            return
        }
        
        eventStore.refreshSourcesIfNecessary()
        
        let now = Date()
        let startPeriod = Calendar.current.date(byAdding: .day, value: -60, to: now) ?? now.addingTimeInterval(-86400 * 60)
        let endPeriod = Calendar.current.date(byAdding: .day, value: 60, to: now) ?? now.addingTimeInterval(86400 * 60)
        
        let allCalendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startPeriod, end: endPeriod, calendars: allCalendars.isEmpty ? nil : allCalendars)
        let ekEvents = eventStore.events(matching: predicate)
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
                title: event.title ?? "Etkinlik",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                meetingURL: meetURL
            ))
        }
        
        let finalItems = items
        await MainActor.run {
            self.upcomingEvents = finalItems
            self.nextEvent = finalItems.first(where: { $0.endDate > now })
            self.updateCountdown()
        }
    }
    
    public func events(for date: Date) -> [CalendarEventItem] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        
        return upcomingEvents.filter { item in
            calendar.isDate(item.startDate, inSameDayAs: date) ||
            calendar.isDate(item.endDate, inSameDayAs: date) ||
            (item.startDate < dayEnd && item.endDate > dayStart)
        }
    }
    
    private func updateCountdown() {
        guard let next = nextEvent else {
            countdownString = ""
            return
        }
        
        let diff = next.startDate.timeIntervalSince(Date())
        let isTurkish = Locale.current.language.languageCode?.identifier.lowercased().starts(with: "tr") ?? true
        
        if diff <= 0 {
            countdownString = isTurkish ? "Şimdi" : "Happening now"
        } else if diff < 3600 {
            let mins = max(1, Int(diff / 60))
            countdownString = isTurkish ? "\(mins) dk sonra" : "in \(mins)m"
        } else {
            let hours = Int(diff / 3600)
            let mins = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            if mins == 0 {
                countdownString = isTurkish ? "\(hours) sa sonra" : "in \(hours)h"
            } else {
                countdownString = isTurkish ? "\(hours) sa \(mins) dk sonra" : "in \(hours)h \(mins)m"
            }
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
