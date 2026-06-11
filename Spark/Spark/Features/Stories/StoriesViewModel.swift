import Foundation
import Observation
import OSLog

@Observable
final class StoriesViewModel {
    weak var coordinator: AppCoordinator?
    private(set) var userState: UserState = UserState()
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var displayedUsers: [StoryUser] = []
    private(set) var scrollTargetUserID: String?
    private(set) var hasReachedEnd = false
    private var currentPage = 1
    private let pageSize = 10
    private(set) var isLoadingMore = false
    private let repository: StoryRepositoryProtocol

    init(repository: StoryRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Load

    func load() async {
        guard !isLoading else { return }
        error = nil
        hasReachedEnd = false
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedUsers = repository.fetchUsers(page: currentPage, limit: pageSize)
            async let fetchedState = repository.fetchState()
            let users = try await fetchedUsers
            userState = await fetchedState
            displayedUsers = users
            if users.isEmpty {
                hasReachedEnd = true
            } else {
                currentPage += 1
                prefetchNextPage()
            }
        } catch {
            self.error = error
            AppLogger.pagination.error("Failed to load stories — \(error, privacy: .public)")
        }
    }

    func prefetchNextPage() {
        Task { await loadMore() }
    }

    func refresh() async {
        let savedPage = currentPage
        currentPage = 1
        await load()
        if error != nil {
            currentPage = savedPage
        }
    }

    func markSeen(storyID: String) {
        userState.seenStoryIDs.insert(storyID)
    }

    /// Keeps the in-memory state in sync with likes made in the detail view,
    /// so reopening a story shows the correct heart state without a refetch.
    func setLiked(storyID: String, liked: Bool) {
        if liked {
            userState.likedStoryIDs.insert(storyID)
        } else {
            userState.likedStoryIDs.remove(storyID)
        }
    }

    func scrollToUser(id: String) {
        scrollTargetUserID = id
    }

    func clearScrollTarget() {
        scrollTargetUserID = nil
    }

    // MARK: - Navigation

    func selectUser(at index: Int) {
        coordinator?.openStories(
            users: displayedUsers,
            startIndex: index,
            userState: userState
        )
    }

    // MARK: - Pagination

    func loadNextPageIfNeeded(currentUser: StoryUser) {
        let threshold = max(pageSize / 2, 3)
        guard !isLoadingMore, !hasReachedEnd,
              let index = displayedUsers.firstIndex(where: { $0.id == currentUser.id }),
              index >= displayedUsers.count - threshold else { return }
        Task { await loadMore() }
    }

    @discardableResult
    func loadMore() async -> [StoryUser] {
        guard !isLoadingMore, !hasReachedEnd else { return displayedUsers }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let more = try await repository.fetchUsers(page: currentPage, limit: pageSize)
            if more.isEmpty {
                hasReachedEnd = true
                return displayedUsers
            }
            displayedUsers.append(contentsOf: more)
            currentPage += 1
        } catch {
            AppLogger.pagination.error("Failed to load page \(self.currentPage) — \(error, privacy: .public)")
        }
        return displayedUsers
    }

    // MARK: - State helpers

    func isSeen(_ user: StoryUser) -> Bool {
        user.stories.allSatisfy { userState.seenStoryIDs.contains($0.id) }
    }
}
