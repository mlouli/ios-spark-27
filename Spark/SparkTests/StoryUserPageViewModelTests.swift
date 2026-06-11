import Testing
import Foundation
@testable import Spark

@Suite("StoryUserPageViewModel")
struct StoryUserPageViewModelTests {
    private let user = makeUser(id: "u1", storyCount: 3)

    private func makeVM(
        repo: MockStoryRepository = MockStoryRepository(),
        likedStoryIDs: Set<String> = [],
        onStorySeen: @escaping (String) -> Void = { _ in }
    ) -> StoryUserPageViewModel {
        var state = UserState()
        state.likedStoryIDs = likedStoryIDs
        return StoryUserPageViewModel(
            user: user,
            userState: state,
            repository: repo,
            onStorySeen: onStorySeen
        )
    }

    // MARK: - Navigation

    @Test func startsAtFirstStory() {
        let vm = makeVM()
        #expect(vm.currentStoryIndex == 0)
        #expect(vm.currentStory.id == user.stories[0].id)
        #expect(vm.hasNext)
        #expect(vm.hasPrevious == false)
    }

    @Test func initReadsLikeStateOfFirstStory() {
        let vm = makeVM(likedStoryIDs: [user.stories[0].id])
        #expect(vm.isLiked)
    }

    @Test func goToNextAdvancesAndUpdatesLikeState() {
        let vm = makeVM(likedStoryIDs: [user.stories[1].id])
        #expect(vm.isLiked == false)
        vm.goToNext()
        #expect(vm.currentStoryIndex == 1)
        #expect(vm.isLiked)
    }

    @Test func goToNextMarksStorySeen() async {
        let repo = MockStoryRepository()
        let recorder = Recorder()
        let vm = makeVM(repo: repo, onStorySeen: { recorder.record($0) })
        vm.goToNext()
        await Task.yield() // let spawned Task start and reach its internal await
        await Task.yield() // let spawned Task resume and complete
        let secondStoryID = user.stories[1].id
        #expect(repo.seenStoryIDs.contains(secondStoryID))
        #expect(recorder.values.contains(secondStoryID))
    }

    @Test func goToNextStopsAtLastStory() {
        let vm = makeVM()
        vm.goToNext()
        vm.goToNext()
        #expect(vm.hasNext == false)
        vm.goToNext()
        #expect(vm.currentStoryIndex == 2)
    }

    @Test func goToPreviousStopsAtFirstStory() {
        let vm = makeVM()
        vm.goToPrevious()
        #expect(vm.currentStoryIndex == 0)
        vm.goToNext()
        vm.goToPrevious()
        #expect(vm.currentStoryIndex == 0)
    }

    // MARK: - Likes

    @Test func toggleLikeIsImmediateAndReachesRepository() async {
        let repo = MockStoryRepository()
        let vm = makeVM(repo: repo)
        vm.toggleLike()
        #expect(vm.isLiked) // optimistic flip, before the repository call lands
        await Task.yield()
        await Task.yield()
        #expect(repo.likeCallArgs.count == 1)
        #expect(repo.likeCallArgs.first?.storyID == user.stories[0].id)
        #expect(repo.likeCallArgs.first?.isLiked == true)
    }

    @Test func toggleLikeTwiceUnlikes() async {
        let repo = MockStoryRepository()
        let vm = makeVM(repo: repo)
        vm.toggleLike()
        await Task.yield()
        await Task.yield()
        vm.toggleLike()
        #expect(vm.isLiked == false)
        await Task.yield()
        await Task.yield()
        #expect(repo.likeCallArgs.count == 2)
        #expect(repo.likeCallArgs.last?.isLiked == false)
    }

    // MARK: - Seen

    @Test func markAllStoriesSeenCoversEveryStory() async {
        let repo = MockStoryRepository()
        let recorder = Recorder()
        let vm = makeVM(repo: repo, onStorySeen: { recorder.record($0) })
        await vm.markAllStoriesSeen()
        let expected = user.stories.map(\.id)
        #expect(repo.seenStoryIDs == expected)
        #expect(recorder.values == expected)
    }

    // MARK: - Pause

    @Test func pauseAndResume() {
        let vm = makeVM()
        vm.pause()
        #expect(vm.isPaused)
        vm.resume()
        #expect(vm.isPaused == false)
    }
}
