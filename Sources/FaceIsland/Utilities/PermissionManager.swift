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
        if #available(macOS 14.0, *) {
            calendarGranted = (status == .fullAccess || status == .writeOnly)
        } else {
            calendarGranted = (status == .authorized)
        }
    }
    
    public func requestCalendarAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .denied || status == .restricted {
            await MainActor.run {
                self.openSettings(for: .calendar)
            }
            return false
        }
        
        let store = EKEventStore()
        do {
            if #available(macOS 14.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                await MainActor.run {
                    self.calendarGranted = granted
                    if !granted {
                        self.openSettings(for: .calendar)
                    }
                }
                return granted
            } else {
                let granted = try await store.requestAccess(to: .event)
                await MainActor.run {
                    self.calendarGranted = granted
                    if !granted {
                        self.openSettings(for: .calendar)
                    }
                }
                return granted
            }
        } catch {
            await MainActor.run {
                self.calendarGranted = false
                self.openSettings(for: .calendar)
            }
            return false
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
