import Foundation
import AppKit

public struct AppAudioItem: Identifiable, Equatable {
    public let id: pid_t
    public let name: String
    public let bundleIdentifier: String?
    public var volume: Float // 0.0 to 1.0
    public var isMuted: Bool
    public var icon: NSImage?
    
    public init(
        id: pid_t,
        name: String,
        bundleIdentifier: String? = nil,
        volume: Float = 1.0,
        isMuted: Bool = false,
        icon: NSImage? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.volume = volume
        self.isMuted = isMuted
        self.icon = icon
    }
}
