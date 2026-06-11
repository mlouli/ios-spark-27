import Foundation

protocol StoryRepositoryProtocol {
    func fetchUsers(page: Int, limit: Int) async throws -> [StoryUser]
    func fetchState() async -> UserState
    func markSeen(storyID: String) async
    func toggleLike(storyID: String, isLiked: Bool) async
    func flushPendingActions() async
}
