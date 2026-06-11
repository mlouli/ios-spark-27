import Testing
@testable import Spark

@Suite("DependencyContainer")
struct DependencyContainerTests {
    @Test func mockContainerUsesInjectedRepository() {
        let repo = MockStoryRepository()
        let container = MockDependencyContainer(repository: repo)
        #expect(container.storyRepository as AnyObject === repo)
    }

    @Test func mockContainerDefaultsToMockRepository() {
        let container = MockDependencyContainer()
        #expect(container.storyRepository is MockStoryRepository)
    }

    @Test func mockContainerSeedsRepositoryState() async {
        var state = UserState()
        state.likedStoryIDs = ["s1"]
        let container = MockDependencyContainer(state: state)
        let fetched = await container.storyRepository.fetchState()
        #expect(fetched.likedStoryIDs == ["s1"])
    }
}
