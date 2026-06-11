import Foundation
import Observation

@Observable
final class AppCoordinator {
    var storyDetailContext: StoryDetailContext?
    private(set) var pendingUserID: String?
    let dependencies: DependencyContainerProtocol

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

    func dismissStories() {
        storyDetailContext = nil
    }

    // spark://story/{userID}
    func handle(url: URL) {
        guard url.scheme == "spark", url.host == "story" else { return }
        pendingUserID = url.lastPathComponent
    }

    func consumePendingUserID() -> String? {
        defer { pendingUserID = nil }
        return pendingUserID
    }
}
