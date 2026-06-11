import Testing
import Foundation
@testable import Spark

@Suite("EmptyStoryRepository")
struct EmptyStoryRepositoryTests {
    @Test func returnsNoUsersAndEmptyState() async throws {
        let repo = EmptyStoryRepository()
        let users = try await repo.fetchUsers(page: 1, limit: 10)
        #expect(users.isEmpty)
        let state = await repo.fetchState()
        #expect(state.seenStoryIDs.isEmpty)
        #expect(state.likedStoryIDs.isEmpty)
    }
}

/// Serialized: all tests share one UserDefaults key (isolated from the app's).
@Suite("LocalStoryRepository", .serialized)
struct LocalStoryRepositoryTests {
    private static let stateKey = "\(AppConfig.bundleID).userState.tests"
    private let repo: LocalStoryRepository

    init() {
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
        repo = LocalStoryRepository(stateKey: Self.stateKey)
    }

    // MARK: - Pagination

    @Test func fetchUsersReturnsRequestedPageSize() async throws {
        let users = try await repo.fetchUsers(page: 1, limit: 7)
        #expect(users.count == 7)
    }

    @Test func pagesHaveUniqueUserIDs() async throws {
        let page1 = try await repo.fetchUsers(page: 1, limit: 10)
        let page2 = try await repo.fetchUsers(page: 2, limit: 10)
        let allIDs = (page1 + page2).map(\.id)
        #expect(Set(allIDs).count == allIDs.count)
    }

    @Test func samePageIsDeterministic() async throws {
        let first = try await repo.fetchUsers(page: 3, limit: 5)
        let second = try await repo.fetchUsers(page: 3, limit: 5)
        #expect(first.map(\.id) == second.map(\.id))
    }

    // MARK: - State persistence

    @Test func freshStateIsEmpty() async {
        let state = await repo.fetchState()
        #expect(state.seenStoryIDs.isEmpty)
        #expect(state.likedStoryIDs.isEmpty)
        #expect(state.pendingActions.isEmpty)
    }

    @Test func markSeenPersists() async {
        await repo.markSeen(storyID: "s1")
        let state = await repo.fetchState()
        #expect(state.seenStoryIDs.contains("s1"))
    }

    @Test func toggleLikePersistsAndUnlikes() async {
        await repo.toggleLike(storyID: "s1", isLiked: true)
        var state = await repo.fetchState()
        #expect(state.likedStoryIDs.contains("s1"))
        await repo.toggleLike(storyID: "s1", isLiked: false)
        state = await repo.fetchState()
        #expect(state.likedStoryIDs.contains("s1") == false)
    }

    @Test func flushClearsPendingActions() async {
        await repo.markSeen(storyID: "s2")
        await repo.flushPendingActions()
        let state = await repo.fetchState()
        #expect(state.pendingActions.isEmpty)
    }
}
