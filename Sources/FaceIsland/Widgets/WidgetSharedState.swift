import Foundation
import SwiftUI
import Combine

public final class WidgetSharedState {
    public static let shared = WidgetSharedState()
    
    public static let appGroupID = "group.com.faceisland.shared"
    public static let stateKey = "FaceIsland_Widget_FaceIDState"
    public static let scanTimestampKey = "FaceIsland_Widget_ScanTimestamp"
    public static let isScanningKey = "FaceIsland_Widget_IsScanning"
    public static let isRecognizedKey = "FaceIsland_Widget_IsRecognized"
    public static let statusTextKey = "FaceIsland_Widget_StatusText"
    
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: WidgetSharedState.appGroupID) ?? UserDefaults.standard
    }
    
    private init() {}
    
    public func updateFaceIDState(isScanning: Bool, isRecognized: Bool, statusText: String) {
        guard SettingsManager.shared.isWidgetSyncEnabled else { return }
        let defaults = sharedDefaults
        defaults?.set(isScanning, forKey: WidgetSharedState.isScanningKey)
        defaults?.set(isRecognized, forKey: WidgetSharedState.isRecognizedKey)
        defaults?.set(statusText, forKey: WidgetSharedState.statusTextKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: WidgetSharedState.scanTimestampKey)
        
        // Post local Darwin/Distributed notification for instant sync
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.faceisland.widget.update"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
    
    public func currentStatus() -> (isScanning: Bool, isRecognized: Bool, statusText: String) {
        let defaults = sharedDefaults
        let isScanning = defaults?.bool(forKey: WidgetSharedState.isScanningKey) ?? false
        let isRecognized = defaults?.bool(forKey: WidgetSharedState.isRecognizedKey) ?? false
        let text = defaults?.string(forKey: WidgetSharedState.statusTextKey) ?? (isScanning ? "Taranıyor..." : (isRecognized ? "Kilit Açıldı" : "Face ID Hazır"))
        return (isScanning, isRecognized, text)
    }
}
