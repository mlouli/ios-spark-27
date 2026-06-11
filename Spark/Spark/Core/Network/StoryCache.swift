import Foundation
import OSLog
import UniformTypeIdentifiers

/// File-based cache for paginated story content.
/// Stored in the system Caches directory — iOS may evict entries under storage
/// pressure, which is acceptable: the app degrades gracefully to a network fetch.
final class StoryCache {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let directory: URL
    private let maxAge: TimeInterval = 24 * 3600 // 24 hours

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("spark_stories", conformingTo: .directory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func store(_ users: [StoryUser], page: Int, limit: Int) {
        if page == 1 { clear() }
        guard let data = try? encoder.encode(users) else {
            AppLogger.cache.warning("Failed to encode stories for page \(page)")
            return
        }
        do {
            try data.write(to: fileURL(page: page, limit: limit))
        } catch {
            AppLogger.cache.warning("Failed to write cache for page \(page) — \(error, privacy: .public)")
        }
    }

    func retrieve(page: Int, limit: Int) -> [StoryUser]? {
        let url = fileURL(page: page, limit: limit)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) > maxAge {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([StoryUser].self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        // Recreate immediately so writes after a clear (e.g. caching a fresh
        // page 1) don't silently fail on the missing parent directory.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(page: Int, limit: Int) -> URL {
        directory.appendingPathComponent("p\(page)_l\(limit).json")
    }
}
