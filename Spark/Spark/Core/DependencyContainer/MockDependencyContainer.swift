import Foundation

final class MockDependencyContainer: DependencyContainerProtocol {
    let storyRepository: StoryRepositoryProtocol

    init(state: UserState = UserState()) {
        storyRepository = MockStoryRepository(state: state)
    }

    init(repository: StoryRepositoryProtocol) {
        storyRepository = repository
    }
}
