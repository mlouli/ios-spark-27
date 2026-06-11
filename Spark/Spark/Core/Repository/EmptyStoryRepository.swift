import Foundation

/// Returns an empty story list. Use in previews to simulate the no-friends/no-stories state.
final class EmptyStoryRepository: StoryRepositoryProtocol {
    func fetchUsers(page: Int, limit: Int) async throws -> [StoryUser] { [] }
    func fetchState() async -> UserState { UserState() }
    func markSeen(storyID: String) async {}
    func toggleLike(storyID: String, isLiked: Bool) async {}
    func flushPendingActions() async {}
}
