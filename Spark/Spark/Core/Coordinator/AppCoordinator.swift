import Foundation
import Observation

@Observable
final class AppCoordinator {
    var storyDetailContext: StoryDetailContext?
	let dependencies: DependencyContainerProtocol

	var storiesViewModel: StoriesViewModel?

    struct StoryDetailContext: Identifiable {
        let id = UUID()
        let users: [StoryUser]
        let startIndex: Int
        let userState: UserState
    }

    init(dependencies: DependencyContainerProtocol) {
        self.dependencies = dependencies
    }

    // MARK: - VM Factory

    func makeStoriesViewModel() -> StoriesViewModel {
        let vm = StoriesViewModel(repository: dependencies.storyRepository)
        vm.coordinator = self
        return vm
    }

    func makeStoryDetailViewModel(
        context: StoryDetailContext,
        loadMore: @escaping () async -> [StoryUser],
        onStorySeen: @escaping (String) -> Void,
        onLikeChanged: @escaping (String, Bool) -> Void = { _, _ in }
    ) -> StoryDetailViewModel {
        let vm = StoryDetailViewModel(
            users: context.users,
            startIndex: context.startIndex,
            userState: context.userState,
            repository: dependencies.storyRepository,
            loadMore: loadMore,
            onStorySeen: onStorySeen,
            onLikeChanged: onLikeChanged
        )
        vm.coordinator = self
        return vm
    }

    // MARK: - Navigation

    func openStories(users: [StoryUser], startIndex: Int, userState: UserState) {
        storyDetailContext = StoryDetailContext(users: users, startIndex: startIndex, userState: userState)
    }

	func dismissStories(lastUserID: String? = nil) {
        storyDetailContext = nil

		if let lastUserID {
			storiesViewModel?.scrollToUser(id: lastUserID)
		}
    }
}
