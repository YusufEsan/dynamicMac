import Foundation
import os.log

public enum LogCategory: String {
    case general = "General"
    case dynamicIsland = "DynamicIsland"
    case faceID = "FaceID"
    case music = "Music"
    case calendar = "Calendar"
    case clipboard = "Clipboard"
    case audio = "Audio"
    case windowSwitcher = "WindowSwitcher"
    case unlock = "Unlock"
}

public final class AppLogger {
    private static let subsystem = "com.faceisland.app"

    public static func debug(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.debug("\(message, privacy: .public)")
    }

    public static func info(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.info("\(message, privacy: .public)")
    }

    public static func error(_ message: String, category: LogCategory = .general) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.error("❌ \(message, privacy: .public)")
    }
}
