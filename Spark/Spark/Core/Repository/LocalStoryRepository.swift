import Foundation
import Network

/// Local repository backed by a bundled JSON file.
/// Simulates server-side pagination by cycling through the dataset with
/// virtual IDs, so the feed feels infinite without a real backend.
/// User state is persisted in UserDefaults with a pending action queue
/// that would flush to a real server when connectivity is restored.
///
/// An actor for the same reason as RemoteStoryRepository: state mutations
/// are read-modify-writes that must not interleave.
actor LocalStoryRepository: StoryRepositoryProtocol {
    private let stateKey: String
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "\(AppConfig.bundleID).networkMonitor")
    private var isConnected = true
    private var sourceUsers: [StoryUser] = []

    init(stateKey: String = "\(AppConfig.bundleID).userState") {
        self.stateKey = stateKey
        monitor.pathUpdateHandler = { [weak self] path in
            // Hop onto the actor — the monitor queue can't touch its state.
            Task { await self?.updateConnectivity(path.status == .satisfied) }
        }
        monitor.start(queue: monitorQueue)
    }

    private func updateConnectivity(_ connected: Bool) async {
        let wasConnected = isConnected
        isConnected = connected
        if !wasConnected && connected {
            await flushPendingActions()
        }
    }

    // MARK: - Fetch

    func fetchUsers(page: Int, limit: Int) async throws -> [StoryUser] {
        if sourceUsers.isEmpty {
            sourceUsers = try loadSource()
        }
        return makePage(page: page, limit: limit)
    }

    func fetchState() async -> UserState {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(UserState.self, from: data) else {
            return UserState()
        }
        return state
    }

    // MARK: - Mutations

    func markSeen(storyID: String) async {
        var state = await fetchState()
        guard !state.seenStoryIDs.contains(storyID) else { return }
        state.seenStoryIDs.insert(storyID)
        state.pendingActions.append(PendingAction(storyID: storyID, type: .seen))
        persist(state)
        if isConnected { await flushPendingActions() }
    }

    func toggleLike(storyID: String, isLiked: Bool) async {
        var state = await fetchState()
        if isLiked {
            state.likedStoryIDs.insert(storyID)
            state.pendingActions.append(PendingAction(storyID: storyID, type: .like))
        } else {
            state.likedStoryIDs.remove(storyID)
            state.pendingActions.append(PendingAction(storyID: storyID, type: .unlike))
        }
        persist(state)
        if isConnected { await flushPendingActions() }
    }

    // MARK: - Sync

    func flushPendingActions() async {
        var state = await fetchState()
        guard !state.pendingActions.isEmpty else { return }
        state.pendingActions.removeAll()
        persist(state)
    }

    // MARK: - Private

    private func loadSource() throws -> [StoryUser] {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json") else {
            throw RepositoryError.missingResource
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([StoryUser].self, from: data)
    }

    private func makePage(page: Int, limit: Int) -> [StoryUser] {
        guard !sourceUsers.isEmpty else { return [] }
        let pageIndex = page - 1
        return (0..<limit).map { i in
            let index = (pageIndex * limit + i) % sourceUsers.count
            let source = sourceUsers[index]
            return StoryUser(
                id: "\(source.id)_p\(pageIndex)i\(i)",
                username: source.username,
                avatarSeed: source.avatarSeed,
                stories: source.stories
            )
        }
    }

    private func persist(_ state: UserState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }
}

enum RepositoryError: Error {
    case missingResource
}
