import Foundation
import AppKit

@Observable
public final class ClipboardManager {
    public static let shared = ClipboardManager()
    
    public var items: [ClipboardItem] = []
    public var retentionDays: Int = 7
    public var selectedSourceFilter: ClipboardDeviceSource? = nil
    public var isMockMode: Bool = false
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    
    public var filteredItems: [ClipboardItem] {
        if let filter = selectedSourceFilter {
            return items.filter { $0.source == filter }
        }
        return items
    }
    
    private init() {
        self.lastChangeCount = 0
        self.items = ClipboardStore.shared.load()
        self.retentionDays = UserDefaults.standard.integer(forKey: "FaceIsland_ClipboardRetentionDays")
        if self.retentionDays == 0 { self.retentionDays = 7 }
        
        // Immediately capture current pasteboard content if not already present
        if let currentText = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentText.isEmpty {
            if !items.contains(where: { $0.text == currentText }) {
                items.insert(ClipboardItem(text: currentText, timestamp: Date(), source: .mac), at: 0)
                ClipboardStore.shared.save(items: items)
            }
        }
        
        startMonitoring()
        iCloudClipboardSync.shared.startSync(manager: self)
        cleanupExpired()
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func checkPasteboard() {
        guard !isMockMode else { return }
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return }
        
        // Prevent immediate duplicates
        if let first = items.first, first.text == string {
            return
        }
        
        // Remove duplicate if exists deeper in list
        items.removeAll { $0.text == string }
        
        // Detect if Universal Clipboard (from iPhone / remote device)
        var source: ClipboardDeviceSource = .mac
        if let types = pasteboard.types {
            let isRemote = types.contains { $0.rawValue.contains("remote") || $0.rawValue.contains("cloud") }
            if isRemote {
                source = .phone
            }
        }
        
        let newItem = ClipboardItem(text: string, timestamp: Date(), source: source)
        items.insert(newItem, at: 0)
        
        if items.count > 500 {
            items = Array(items.prefix(500))
        }
        
        saveAndSync()
    }
    
    public func copyToPasteboard(item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }
    
    public func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveAndSync()
    }
    
    public func togglePin(id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isPinned.toggle()
            saveAndSync()
        }
    }
    
    public func clearAllNonPinned() {
        items.removeAll { !$0.isPinned }
        saveAndSync()
    }
    
    public func updateRetentionDays(_ days: Int) {
        self.retentionDays = max(1, min(30, days))
        UserDefaults.standard.set(self.retentionDays, forKey: "FaceIsland_ClipboardRetentionDays")
        cleanupExpired()
    }
    
    public func cleanupExpired() {
        ClipboardStore.shared.purgeExpired(items: &items, retentionDays: retentionDays)
    }
    
    public func mergeRemoteItems(_ remoteItems: [ClipboardItem]) {
        for remote in remoteItems {
            if !items.contains(where: { $0.text == remote.text }) {
                items.append(remote)
            }
        }
        items.sort { $0.timestamp > $1.timestamp }
        saveAndSync(pushToCloud: false)
    }
    
    private func saveAndSync(pushToCloud: Bool = true) {
        ClipboardStore.shared.save(items: items)
        if pushToCloud {
            iCloudClipboardSync.shared.syncLocalItems(items)
        }
    }
}
