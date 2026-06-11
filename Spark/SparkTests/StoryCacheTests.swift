import Testing
import Foundation
@testable import Spark

/// Serialized: all tests share the real on-disk cache directory.
@Suite("StoryCache", .serialized)
struct StoryCacheTests {
    private let cache: StoryCache

    init() {
        cache = StoryCache()
        cache.clear()
    }

    @Test func storeAndRetrieveRoundTrip() {
        let users = makeUsers(count: 3)
        cache.store(users, page: 2, limit: 10)
        #expect(cache.retrieve(page: 2, limit: 10) == users)
    }

    @Test func retrieveMissingPageReturnsNil() {
        #expect(cache.retrieve(page: 9, limit: 10) == nil)
    }

    @Test func retrieveDistinguishesLimit() {
        cache.store(makeUsers(count: 2), page: 2, limit: 10)
        #expect(cache.retrieve(page: 2, limit: 5) == nil)
    }

    @Test func storingPageOneClearsOlderPages() {
        cache.store(makeUsers(count: 2, prefix: "old"), page: 2, limit: 10)
        cache.store(makeUsers(count: 2, prefix: "fresh"), page: 1, limit: 10)
        #expect(cache.retrieve(page: 2, limit: 10) == nil)
        #expect(cache.retrieve(page: 1, limit: 10)?.first?.id == "fresh_0")
    }

    @Test func clearRemovesEverythingAndAllowsNewWrites() {
        cache.store(makeUsers(count: 2), page: 1, limit: 10)
        cache.clear()
        #expect(cache.retrieve(page: 1, limit: 10) == nil)
        cache.store(makeUsers(count: 2), page: 2, limit: 10)
        #expect(cache.retrieve(page: 2, limit: 10) != nil)
    }

    @Test func expiredEntriesAreEvicted() throws {
        cache.store(makeUsers(count: 2), page: 2, limit: 10)
        let file = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("spark_stories")
            .appendingPathComponent("p2_l10.json")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -25 * 3600)],
            ofItemAtPath: file.path
        )
        #expect(cache.retrieve(page: 2, limit: 10) == nil)
        #expect(FileManager.default.fileExists(atPath: file.path) == false)
    }
}
