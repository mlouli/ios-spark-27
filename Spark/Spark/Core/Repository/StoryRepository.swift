import Foundation

protocol StoryRepositoryProtocol {
    func fetchUsers(page: Int, limit: Int) async throws -> [StoryUser]
    func fetchState() async -> UserState
    func markSeen(storyID: String) async
    /// Batch variant: one state read/write and one flush for the whole set,
    /// instead of a write + network flush per story.
    func markSeen(storyIDs: [String]) async
    func toggleLike(storyID: String, isLiked: Bool) async
    func flushPendingActions() async
}
