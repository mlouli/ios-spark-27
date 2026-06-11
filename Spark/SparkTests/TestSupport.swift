import Foundation
@testable import Spark

enum TestError: Error {
    case network
}

// MARK: - Factories

/// Whole-second timestamp so Codable round-trips through ISO8601 stay equal.
func makeStory(id: String, seed: String = "seed", caption: String = "caption") -> Story {
    Story(
        id: id,
        imageSeed: seed,
        caption: caption,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

func makeUser(id: String, storyCount: Int = 2) -> StoryUser {
    StoryUser(
        id: id,
        username: "user_\(id)",
        avatarSeed: "avatar_\(id)",
        stories: (0..<storyCount).map { makeStory(id: "\(id)_story_\($0)") }
    )
}

func makeUsers(count: Int, prefix: String = "user") -> [StoryUser] {
    (0..<count).map { makeUser(id: "\(prefix)_\($0)") }
}

// MARK: - Async helpers

/// Polls a condition until it becomes true or the timeout elapses.
/// Used to await fire-and-forget Tasks spawned by view models.
@discardableResult
func eventually(timeout: TimeInterval = 2, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// Thread-safe collector for callback arguments recorded across tasks.
final class Recorder {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }
}
