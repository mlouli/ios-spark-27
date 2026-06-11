import Testing
import Foundation
@testable import Spark

@Suite("StoriesViewModel")
struct StoriesViewModelTests {
    // MARK: - load

    @Test func loadPopulatesUsersAndState() async {
        var state = UserState()
        state.likedStoryIDs = ["liked_story"]
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")]], state: state)
        let vm = StoriesViewModel(repository: repo)
        await vm.load()
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
        #expect(vm.displayedUsers.first?.id == "u1")
        #expect(vm.userState.likedStoryIDs == ["liked_story"])
    }

    @Test func loadPrefetchesSecondPage() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")], [makeUser(id: "u2")]])
        let vm = StoriesViewModel(repository: repo)
        await vm.load()
        let settled = await eventually { vm.displayedUsers.count == 2 }
        #expect(settled)
        #expect(repo.fetchedPages.contains(2))
    }

    @Test func loadFailureSetsErrorAndSkipsPrefetch() async {
        let repo = MockStoryRepository()
        repo.fetchError = TestError.network
        let vm = StoriesViewModel(repository: repo)
        await vm.load()
        #expect(vm.error != nil)
        #expect(vm.displayedUsers.isEmpty)
        #expect(repo.fetchUsersCallCount == 1)
    }

    @Test func loadEmptyFirstPageReachesEnd() async {
        let repo = MockStoryRepository(pages: [[]])
        let vm = StoriesViewModel(repository: repo)
        await vm.load()
        #expect(vm.hasReachedEnd)
        #expect(vm.displayedUsers.isEmpty)
        #expect(repo.fetchUsersCallCount == 1)
    }

    @Test func loadClearsPreviousError() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")]])
        repo.fetchError = TestError.network
        let vm = StoriesViewModel(repository: repo)
        await vm.load()
        #expect(vm.error != nil)
        repo.fetchError = nil
        await vm.load()
        #expect(vm.error == nil)
        #expect(vm.displayedUsers.count == 1)
    }

    // MARK: - loadMore

    @Test func loadMoreAppendsPagesSequentially() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")], [makeUser(id: "u2")]])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        #expect(vm.displayedUsers.map(\.id) == ["u1"])
        await vm.loadMore()
        #expect(vm.displayedUsers.map(\.id) == ["u1", "u2"])
        #expect(repo.fetchedPages == [1, 2])
    }

    @Test func loadMoreEmptyResponseStopsPagination() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")]])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        await vm.loadMore() // page 2 → [] → end of feed
        #expect(vm.hasReachedEnd)
        await vm.loadMore() // guarded, must not hit the repository
        #expect(repo.fetchUsersCallCount == 2)
    }

    @Test func loadMoreFailureRetriesSamePage() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")]])
        repo.fetchError = TestError.network
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        #expect(vm.displayedUsers.isEmpty)
        repo.fetchError = nil
        await vm.loadMore()
        #expect(vm.displayedUsers.count == 1)
        #expect(repo.fetchedPages == [1, 1])
    }

    // MARK: - refresh

    @Test func refreshRestartsFromPageOne() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")], [makeUser(id: "u2")]])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        await vm.loadMore()
        #expect(vm.displayedUsers.count == 2)
        await vm.refresh()
        #expect(vm.displayedUsers.first?.id == "u1")
        let settled = await eventually { vm.displayedUsers.count == 2 }
        #expect(settled)
        #expect(vm.displayedUsers.map(\.id) == ["u1", "u2"])
    }

    @Test func refreshFailureKeepsContentAndRestoresPage() async {
        let repo = MockStoryRepository(pages: [[makeUser(id: "u1")], [makeUser(id: "u2")]])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        await vm.loadMore() // next page to fetch is now 3
        repo.fetchError = TestError.network
        await vm.refresh()
        #expect(vm.error != nil)
        #expect(vm.displayedUsers.count == 2)
        repo.fetchError = nil
        await vm.loadMore()
        #expect(repo.fetchedPages.last == 3)
    }

    // MARK: - loadNextPageIfNeeded

    @Test func loadNextPageTriggersWithinThreshold() async {
        let page1 = makeUsers(count: 10, prefix: "p1")
        let repo = MockStoryRepository(pages: [page1])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        vm.loadNextPageIfNeeded(currentUser: page1[5])
        let triggered = await eventually { repo.fetchUsersCallCount == 2 }
        #expect(triggered)
    }

    @Test func loadNextPageIgnoresUsersBeforeThreshold() async {
        let page1 = makeUsers(count: 10, prefix: "p1")
        let repo = MockStoryRepository(pages: [page1])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        vm.loadNextPageIfNeeded(currentUser: page1[0])
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.fetchUsersCallCount == 1)
    }

    @Test func loadNextPageIgnoredAfterEndOfFeed() async {
        let page1 = makeUsers(count: 10, prefix: "p1")
        let repo = MockStoryRepository(pages: [page1])
        let vm = StoriesViewModel(repository: repo)
        await vm.loadMore()
        await vm.loadMore() // [] → end of feed
        vm.loadNextPageIfNeeded(currentUser: page1[9])
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.fetchUsersCallCount == 2)
    }

    // MARK: - State helpers

    @Test func markSeenInsertsIntoUserState() {
        let vm = StoriesViewModel(repository: MockStoryRepository())
        vm.markSeen(storyID: "s1")
        #expect(vm.userState.seenStoryIDs.contains("s1"))
    }

    @Test func isSeenRequiresAllStoriesSeen() {
        let vm = StoriesViewModel(repository: MockStoryRepository())
        let user = makeUser(id: "u1", storyCount: 2)
        vm.markSeen(storyID: user.stories[0].id)
        #expect(vm.isSeen(user) == false)
        vm.markSeen(storyID: user.stories[1].id)
        #expect(vm.isSeen(user))
    }

    @Test func setLikedUpdatesUserState() {
        let vm = StoriesViewModel(repository: MockStoryRepository())
        vm.setLiked(storyID: "s1", liked: true)
        #expect(vm.userState.likedStoryIDs.contains("s1"))
        vm.setLiked(storyID: "s1", liked: false)
        #expect(vm.userState.likedStoryIDs.contains("s1") == false)
    }

    @Test func scrollTargetLifecycle() {
        let vm = StoriesViewModel(repository: MockStoryRepository())
        vm.scrollToUser(id: "u7")
        #expect(vm.scrollTargetUserID == "u7")
        vm.clearScrollTarget()
        #expect(vm.scrollTargetUserID == nil)
    }

    // MARK: - Navigation

    @Test func selectUserOpensStoryDetail() async {
        let repo = MockStoryRepository(pages: [makeUsers(count: 3)])
        let coordinator = AppCoordinator(dependencies: MockDependencyContainer(repository: repo))
        let vm = coordinator.makeStoriesViewModel()
        await vm.loadMore()
        vm.selectUser(at: 1)
        #expect(coordinator.storyDetailContext?.startIndex == 1)
        #expect(coordinator.storyDetailContext?.users.count == 3)
    }
}
