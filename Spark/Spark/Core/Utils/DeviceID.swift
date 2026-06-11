import Foundation

enum DeviceID {
    nonisolated(unsafe) static var current: String {
        let key = "\(AppConfig.bundleID).deviceID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}
