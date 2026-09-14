import Foundation
import AppKit

public struct WindowItem: Identifiable, Equatable {
    public let id: CGWindowID
    public let processIdentifier: pid_t
    public let appName: String
    public let windowTitle: String
    public let bounds: CGRect
    public var thumbnail: NSImage?
    public var appIcon: NSImage?
    
    public init(
        id: CGWindowID,
        processIdentifier: pid_t,
        appName: String,
        windowTitle: String,
        bounds: CGRect,
        thumbnail: NSImage? = nil,
        appIcon: NSImage? = nil
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.appName = appName
        self.windowTitle = windowTitle
        self.bounds = bounds
        self.thumbnail = thumbnail
        self.appIcon = appIcon
    }
}
