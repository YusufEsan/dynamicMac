import Foundation

public final class CloudKitManager {
    public static let shared = CloudKitManager()
    
    private let kvs = NSUbiquitousKeyValueStore.default
    private let syncKey = "FaceIsland_iCloud_Clipboard"
    
    public var onRemoteChange: (([ClipboardItem]) -> Void)?
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousKeyValueStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
        kvs.synchronize()
    }
    
    @objc private func ubiquitousKeyValueStoreDidChange(notification: Notification) {
        guard let changeReason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              changeReason == NSUbiquitousKeyValueStoreServerChange || changeReason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }
        
        if let data = kvs.data(forKey: syncKey) {
            do {
                let items = try JSONDecoder().decode([ClipboardItem].self, from: data)
                AppLogger.info("Received \(items.count) items from iCloud sync", category: .clipboard)
                DispatchQueue.main.async {
                    self.onRemoteChange?(items)
                }
            } catch {
                AppLogger.error("Error decoding iCloud clipboard: \(error)", category: .clipboard)
            }
        }
    }
    
    public func pushToCloud(items: [ClipboardItem]) {
        // Keep the latest 20 items for lightweight KVS sync
        let latest = Array(items.prefix(20))
        if let data = try? JSONEncoder().encode(latest) {
            kvs.set(data, forKey: syncKey)
            kvs.synchronize()
        }
    }
}
