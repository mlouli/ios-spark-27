import Foundation
import OSLog

enum AppConfig {
	static let bundleID = Bundle.main.bundleIdentifier ?? "app.spark.Spark"
}

enum AppLogger {
    static let network    = Logger(subsystem: AppConfig.bundleID, category: "network")
    static let cache      = Logger(subsystem: AppConfig.bundleID, category: "cache")
    static let repository = Logger(subsystem: AppConfig.bundleID, category: "repository")
    static let pagination = Logger(subsystem: AppConfig.bundleID, category: "pagination")
}
