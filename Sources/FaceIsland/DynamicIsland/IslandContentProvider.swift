import Foundation
import SwiftUI

public enum IslandModuleType: String, CaseIterable, Identifiable {
    case faceID = "Face ID"
    case music = "Music"
    case calendar = "Calendar"
    case clipboard = "Clipboard"
    case audio = "Audio"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .faceID: return "faceid"
        case .music: return "music.note"
        case .calendar: return "calendar"
        case .clipboard: return "doc.on.clipboard"
        case .audio: return "speaker.wave.2"
        }
    }
}

public enum IslandExpansionState: Equatable {
    case compact
    case expanded(IslandModuleType)
    case faceIDScanning
}

@Observable
public final class IslandContentProvider {
    public static let shared = IslandContentProvider()
    
    public var expansionState: IslandExpansionState = .compact {
        didSet {
            onStateChanged?(expansionState)
        }
    }
    public var activeModule: IslandModuleType = .faceID
    public var isHovered: Bool = false
    public var isPinnedExpanded: Bool = false
    public var currentVisualWidth: CGFloat = 320 {
        didSet {
            if abs(currentVisualWidth - oldValue) > 1.0 {
                onStateChanged?(expansionState)
            }
        }
    }
    public var currentVisualHeight: CGFloat = 35 {
        didSet {
            if abs(currentVisualHeight - oldValue) > 1.0 {
                onStateChanged?(expansionState)
            }
        }
    }
    
    public var onStateChanged: ((IslandExpansionState) -> Void)?
    
    private init() {
        listenToFaceID()
    }
    
    private func listenToFaceID() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(faceRecognizedNotificationReceived(_:)),
            name: FaceRecognitionManager.faceRecognizedNotification,
            object: nil
        )
    }
    
    @objc private func faceRecognizedNotificationReceived(_ notification: Notification) {
        DispatchQueue.main.async {
            // Keep in compact mode or smooth spring feedback without forced expansion unless user clicked
            print("✨ [IslandContentProvider] Face ID Recognized received successfully!")
        }
    }
    
    public func selectModule(_ module: IslandModuleType) {
        if self.activeModule == module && expansionState != .compact {
            // Clicking same module collapses the island
            self.collapse()
        } else {
            self.activeModule = module
            self.expansionState = .expanded(module)
        }
    }
    
    public func expand(to module: IslandModuleType = .faceID) {
        self.activeModule = module
        self.isPinnedExpanded = true
        self.expansionState = .expanded(module)
    }
    
    public func collapse() {
        self.isPinnedExpanded = false
        self.expansionState = .compact
    }
    
    public func toggleExpand() {
        if case .compact = expansionState {
            expansionState = .expanded(activeModule)
        } else {
            collapse()
        }
    }
}
