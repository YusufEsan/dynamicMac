import AVFoundation
import AppKit
import EventKit

@Observable
public final class PermissionManager {
    public static let shared = PermissionManager()
    
    public var cameraGranted: Bool = false
    public var accessibilityGranted: Bool = false
    public var calendarGranted: Bool = false
    public var screenRecordingGranted: Bool = false
    
    private init() {
        checkAll()
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.checkAll()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.checkAll()
        }
    }
    
    public func checkAll() {
        checkCamera()
        checkAccessibility()
        checkCalendar()
        checkScreenRecording()
    }
    
    public func checkCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraGranted = true
        case .notDetermined:
            cameraGranted = false
        default:
            cameraGranted = false
        }
    }
    
    public func requestCameraAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.cameraGranted = granted
        }
        return granted
    }
    
    public func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }
    
    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }
    
    public func checkCalendar() {
        let status = EKEventStore.authorizationStatus(for: .event)
        var isGranted = (status == .fullAccess || status == .writeOnly || status == .authorized)
        
        if !isGranted {
            let store = EKEventStore()
            if !store.calendars(for: .event).isEmpty {
                isGranted = true
            }
        }
        
        if calendarGranted != isGranted {
            calendarGranted = isGranted
            if isGranted {
                Task {
                    await CalendarManager.shared.fetchEvents()
                }
            }
        }
    }
    
    public func requestCalendarAccess() async -> Bool {
        let store = EKEventStore()
        if !store.calendars(for: .event).isEmpty {
            await MainActor.run {
                self.calendarGranted = true
                Task { await CalendarManager.shared.fetchEvents() }
            }
            return true
        }
        
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .denied || status == .restricted {
            await MainActor.run {
                self.openSettings(for: .calendar)
            }
            return false
        }
        
        do {
            var granted = false
            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            
            let verifiedStatus = EKEventStore.authorizationStatus(for: .event)
            if verifiedStatus == .fullAccess || verifiedStatus == .writeOnly || verifiedStatus == .authorized || !store.calendars(for: .event).isEmpty {
                granted = true
            }
            
            let finalGranted = granted
            await MainActor.run {
                self.calendarGranted = finalGranted
                if finalGranted {
                    Task {
                        await CalendarManager.shared.fetchEvents()
                    }
                } else {
                    self.openSettings(for: .calendar)
                }
            }
            return finalGranted
        } catch {
            await MainActor.run {
                self.checkCalendar()
                if !self.calendarGranted {
                    self.openSettings(for: .calendar)
                }
            }
            return self.calendarGranted
        }
    }
    
    public func checkScreenRecording() {
        if #available(macOS 11.0, *) {
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        } else {
            screenRecordingGranted = true
        }
    }
    
    public func requestScreenRecording() {
        if #available(macOS 11.0, *) {
            CGRequestScreenCaptureAccess()
            checkScreenRecording()
        }
    }
    
    public enum PermissionType {
        case camera
        case accessibility
        case screenRecording
        case calendar
    }
    
    public func openSettings(for type: PermissionType) {
        let urlString: String
        switch type {
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .calendar:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
