import Foundation

// Test/preview double — excluded from release builds.
#if DEBUG

final class MockDependencyContainer: DependencyContainerProtocol {
    let storyRepository: StoryRepositoryProtocol

    init(state: UserState = UserState()) {
        storyRepository = MockStoryRepository(state: state)
    }

    init(repository: StoryRepositoryProtocol) {
        storyRepository = repository
    }
}
#endif
