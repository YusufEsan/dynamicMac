import Foundation
import AppKit

public final class iCloudClipboardSync {
    public static let shared = iCloudClipboardSync()
    
    private init() {}
    
    public func startSync(manager: ClipboardManager) {
        CloudKitManager.shared.onRemoteChange = { [weak manager] remoteItems in
            manager?.mergeRemoteItems(remoteItems)
        }
    }
    
    public func syncLocalItems(_ items: [ClipboardItem]) {
        CloudKitManager.shared.pushToCloud(items: items)
    }
}
