import Foundation
import Observation

@Observable
final class StoryDetailViewModel {
    weak var coordinator: AppCoordinator?
    private(set) var users: [StoryUser]
    let startUserID: String
    let userState: UserState
    private let repository: StoryRepositoryProtocol
    private let loadMore: () async -> [StoryUser]
    private let onStorySeen: (String) -> Void
    private let onLikeChanged: (String, Bool) -> Void
    private var pageViewModels: [String: StoryUserPageViewModel] = [:]

    init(
        users: [StoryUser],
        startIndex: Int,
        userState: UserState,
        repository: StoryRepositoryProtocol,
        loadMore: @escaping () async -> [StoryUser],
        onStorySeen: @escaping (String) -> Void,
        onLikeChanged: @escaping (String, Bool) -> Void = { _, _ in }
    ) {
        self.users = users
        self.startUserID = users[startIndex].id
        self.userState = userState
        self.repository = repository
        self.loadMore = loadMore
        self.onStorySeen = onStorySeen
        self.onLikeChanged = onLikeChanged
    }

    // MARK: - Page VM Factory

    func pageViewModel(for user: StoryUser) -> StoryUserPageViewModel {
        if let vm = pageViewModels[user.id] { return vm }
        let vm = StoryUserPageViewModel(
            user: user,
            userState: userState,
            repository: repository,
            onStorySeen: onStorySeen,
            onLikeChanged: onLikeChanged
        )
        pageViewModels[user.id] = vm
        return vm
    }

    // MARK: - Navigation

    func onScrolled(to id: String?) {
        guard let id, let i = users.firstIndex(where: { $0.id == id }) else { return }
        if i >= users.count - 2 {
            Task { users = await loadMore() }
        }
    }
}
