import Foundation
import AppKit

public enum ClipboardDeviceSource: String, Codable, CaseIterable {
    case mac = "mac"
    case phone = "phone"
    
    public var iconName: String {
        switch self {
        case .mac: return "laptopcomputer"
        case .phone: return "iphone"
        }
    }
    
    public var displayName: String {
        switch self {
        case .mac: return "Mac"
        case .phone: return "iPhone"
        }
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var text: String
    public var timestamp: Date
    public var source: ClipboardDeviceSource
    public var isPinned: Bool
    public var charCount: Int { text.count }
    
    public init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        source: ClipboardDeviceSource = .mac,
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.source = source
        self.isPinned = isPinned
    }
}
