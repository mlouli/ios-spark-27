import Testing
import Foundation
@testable import Spark

@Suite("StoryDetailViewModel")
struct StoryDetailViewModelTests {
    private func makeVM(
        users: [StoryUser],
        startIndex: Int = 0,
        loadMore: @escaping () async -> [StoryUser] = { [] }
    ) -> StoryDetailViewModel {
        StoryDetailViewModel(
            users: users,
            startIndex: startIndex,
            userState: UserState(),
            repository: MockStoryRepository(),
            loadMore: loadMore,
            onStorySeen: { _ in }
        )
    }

    @Test func startUserIDMatchesStartIndex() {
        let users = makeUsers(count: 3)
        let vm = makeVM(users: users, startIndex: 2)
        #expect(vm.startUserID == users[2].id)
    }

    @Test func pageViewModelIsCachedPerUser() {
        let users = makeUsers(count: 2)
        let vm = makeVM(users: users)
        let first = vm.pageViewModel(for: users[0])
        let second = vm.pageViewModel(for: users[0])
        let other = vm.pageViewModel(for: users[1])
        #expect(first === second)
        #expect(first !== other)
    }

    @Test func onScrolledNearEndRequestsMoreUsers() async {
        let users = makeUsers(count: 3)
        let expanded = users + [makeUser(id: "extra")]
        let vm = makeVM(users: users, loadMore: { expanded })
        vm.onScrolled(to: users[1].id) // index 1 >= count - 2 → load more
        let grew = await eventually { vm.users.count == 4 }
        #expect(grew)
        #expect(vm.users.last?.id == "extra")
    }

    @Test func onScrolledEarlyDoesNotRequestMore() async {
        let users = makeUsers(count: 4)
        let recorder = Recorder()
        let vm = makeVM(users: users, loadMore: {
            recorder.record("called")
            return users
        })
        vm.onScrolled(to: users[0].id) // index 0 < count - 2
        try? await Task.sleep(for: .milliseconds(100))
        #expect(recorder.values.isEmpty)
    }

    @Test func onScrolledWithNilOrUnknownIDDoesNothing() async {
        let users = makeUsers(count: 2)
        let recorder = Recorder()
        let vm = makeVM(users: users, loadMore: {
            recorder.record("called")
            return users
        })
        vm.onScrolled(to: nil)
        vm.onScrolled(to: "ghost")
        try? await Task.sleep(for: .milliseconds(100))
        #expect(recorder.values.isEmpty)
    }
}
