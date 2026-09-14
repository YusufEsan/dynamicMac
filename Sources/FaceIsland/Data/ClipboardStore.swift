import Foundation

public final class ClipboardStore {
    public static let shared = ClipboardStore()
    
    private let fileManager = FileManager.default
    private let fileName = "faceisland_clipboard.json"
    
    private var fileURL: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("FaceIsland", isDirectory: true)
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent(fileName)
    }
    
    private init() {}
    
    public func save(items: [ClipboardItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            AppLogger.error("Failed to save clipboard items: \(error.localizedDescription)", category: .clipboard)
        }
    }
    
    public func load() -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            AppLogger.error("Failed to load clipboard items: \(error.localizedDescription)", category: .clipboard)
            return []
        }
    }
    
    public func purgeExpired(items: inout [ClipboardItem], retentionDays: Int) {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
        
        items.removeAll { item in
            !item.isPinned && item.timestamp < cutoffDate
        }
        save(items: items)
    }
}
