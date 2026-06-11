import Foundation

final class MockStoryRepository: StoryRepositoryProtocol {
    // MARK: - Configuration

    /// Pages of users returned by fetchUsers. Index 0 = page 1, index 1 = page 2, etc.
    /// Returns [] for any page beyond the last configured page.
    var pages: [[StoryUser]]

    /// When set, fetchUsers throws this error instead of returning data.
    var fetchError: Error?

    /// The UserState returned by fetchState.
    var stateToReturn: UserState

    // MARK: - Call tracking

    private(set) var fetchUsersCallCount = 0
    private(set) var fetchedPages: [Int] = []
    private(set) var seenStoryIDs: [String] = []
    private(set) var likeCallArgs: [(storyID: String, isLiked: Bool)] = []
    private(set) var flushCallCount = 0

    // MARK: - Live mutable state (mirrors what a real repo would do)

    private(set) var state: UserState

    // MARK: - Init

    init(
        pages: [[StoryUser]] = [[PreviewMocks.user, PreviewMocks.seenUser]],
        state: UserState = UserState()
    ) {
        self.pages = pages
        self.state = state
        self.stateToReturn = state
    }

    // MARK: - StoryRepositoryProtocol

    func fetchUsers(page: Int, limit: Int) async throws -> [StoryUser] {
        fetchUsersCallCount += 1
        fetchedPages.append(page)
        if let error = fetchError { throw error }
        let index = page - 1
        guard index >= 0, index < pages.count else { return [] }
        return pages[index]
    }

    func fetchState() async -> UserState {
        stateToReturn
    }

    func markSeen(storyID: String) async {
        seenStoryIDs.append(storyID)
        state.seenStoryIDs.insert(storyID)
    }

    func toggleLike(storyID: String, isLiked: Bool) async {
        likeCallArgs.append((storyID, isLiked))
        if isLiked {
            state.likedStoryIDs.insert(storyID)
        } else {
            state.likedStoryIDs.remove(storyID)
        }
    }

    func flushPendingActions() async {
        flushCallCount += 1
    }

    // MARK: - Helpers

    func reset() {
        fetchUsersCallCount = 0
        fetchedPages = []
        seenStoryIDs = []
        likeCallArgs = []
        flushCallCount = 0
        fetchError = nil
    }
}
