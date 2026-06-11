import Testing
import Foundation
@testable import Spark

@Suite("AppCoordinator")
struct AppCoordinatorTests {
    private func makeCoordinator() -> AppCoordinator {
        AppCoordinator(dependencies: MockDependencyContainer())
    }

    @Test func openAndDismissStories() {
        let coordinator = makeCoordinator()
        let users = makeUsers(count: 2)
        coordinator.openStories(users: users, startIndex: 1, userState: UserState())
        #expect(coordinator.storyDetailContext?.users.count == 2)
        #expect(coordinator.storyDetailContext?.startIndex == 1)
        coordinator.dismissStories()
        #expect(coordinator.storyDetailContext == nil)
    }

    @Test func makeStoriesViewModelWiresCoordinator() {
        let coordinator = makeCoordinator()
        let vm = coordinator.makeStoriesViewModel()
        #expect(vm.coordinator === coordinator)
    }

    @Test func makeStoryDetailViewModelWiresCoordinatorAndContext() {
        let coordinator = makeCoordinator()
        let users = makeUsers(count: 2)
        let context = AppCoordinator.StoryDetailContext(
            users: users,
            startIndex: 1,
            userState: UserState()
        )
        let vm = coordinator.makeStoryDetailViewModel(
            context: context,
            loadMore: { [] },
            onStorySeen: { _ in }
        )
        #expect(vm.coordinator === coordinator)
        #expect(vm.startUserID == users[1].id)
    }
}
