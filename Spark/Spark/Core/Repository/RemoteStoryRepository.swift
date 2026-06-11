import Foundation
import Network
import OSLog

/// Production repository backed by the Spark Vercel API.
/// Follows the server-as-source-of-truth pattern:
/// - Content (stories) is always fetched from the server.
/// - User state is fetched from the server at launch and cached locally.
/// - Mutations are applied optimistically to the local cache, queued as
///   pending actions, and flushed to the server when connectivity allows.
///
/// An actor: every mutation is a read-modify-write of the persisted state,
/// and a flush overlapping a toggle could otherwise drop pending actions.
actor RemoteStoryRepository: StoryRepositoryProtocol {
	private let client: NetworkClient
	private let cache: StoryCache
    private let stateKey = "\(AppConfig.bundleID).remoteUserState"
    private let userID = DeviceID.current
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "\(AppConfig.bundleID).remoteNetworkMonitor")
    private var isConnected = true
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
		self.client = NetworkClient()
		self.cache = StoryCache()

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
        // Offline: return cache immediately — no point waiting for a timeout.
        if !isConnected, let cached = cache.retrieve(page: page, limit: limit) {
            return cached
        }
        do {
            let users: [StoryUser] = try await client.request(.stories(page: page, limit: limit))
            cache.store(users, page: page, limit: limit)
            return users
        } catch {
            // Network failed — serve stale cache rather than an empty screen.
            if let cached = cache.retrieve(page: page, limit: limit) {
                AppLogger.repository.info("Serving cached stories for page \(page) after network failure")
                return cached
            }
            throw error
        }
    }

    func fetchState() async -> UserState {
        do {
            let remote: RemoteUserState = try await client.request(.state(userID: userID))
            var state = UserState()
            state.likedStoryIDs = Set(remote.likedStoryIDs)
            state.seenStoryIDs = Set(remote.seenStoryIDs)
            persistState(state)
            return state
        } catch {
            AppLogger.repository.warning("fetchState failed, using local cache — \(error, privacy: .public)")
            return cachedState()
        }
    }

    // MARK: - Mutations

    func markSeen(storyID: String) async {
        await markSeen(storyIDs: [storyID])
    }

    func markSeen(storyIDs: [String]) async {
        var state = cachedState()
        let new = storyIDs.filter { !state.seenStoryIDs.contains($0) }
        guard !new.isEmpty else { return }
        for storyID in new {
            state.seenStoryIDs.insert(storyID)
            state.pendingActions.append(PendingAction(storyID: storyID, type: .seen))
        }
        persistState(state)
        if isConnected { await flushPendingActions() }
    }

    func toggleLike(storyID: String, isLiked: Bool) async {
        var state = cachedState()
        if isLiked {
            state.likedStoryIDs.insert(storyID)
            state.pendingActions.append(PendingAction(storyID: storyID, type: .like))
        } else {
            state.likedStoryIDs.remove(storyID)
            state.pendingActions.append(PendingAction(storyID: storyID, type: .unlike))
        }
        persistState(state)
        if isConnected { await flushPendingActions() }
    }

    // MARK: - Sync

    /// Only one flush loop runs at a time — concurrent callers return
    /// immediately and their freshly queued actions are picked up by the
    /// running loop's next pass. Without this, every markSeen/toggleLike
    /// will spawn its own serial network loop over the same queue.
    private var isFlushing = false

    func flushPendingActions() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        while true {
            let batch = cachedState().pendingActions
            guard !batch.isEmpty else { return }

            var failed: [PendingAction] = []
            for action in batch {
                do {
                    try await performWithBackoff {
                        switch action.type {
                        case .seen:
                            try await self.client.request(.seen(userID: self.userID, storyID: action.storyID))
                        case .like:
                            try await self.client.request(.like(userID: self.userID, storyID: action.storyID, isLiked: true))
                        case .unlike:
                            try await self.client.request(.like(userID: self.userID, storyID: action.storyID, isLiked: false))
                        }
                    }
                } catch {
                    AppLogger.repository.error("Pending action failed permanently: \(action.storyID, privacy: .public) \(action.type.rawValue, privacy: .public) — \(error, privacy: .public)")
                    failed.append(action)
                }
            }

            // Merge instead of overwrite: actions appended while we were
            // sending (the actor suspends at every network await) must survive.
            var state = cachedState()
            let batchIDs = Set(batch.map(\.id))
            let appendedMidFlight = state.pendingActions.filter { !batchIDs.contains($0.id) }
            state.pendingActions = failed + appendedMidFlight
            persistState(state)

            // Loop again only for fresh work we can plausibly send — if the
            // whole batch failed, retrying immediately would spin.
            guard !appendedMidFlight.isEmpty, failed.count < batch.count else { return }
        }
    }

    // Retries up to 3 times with exponential backoff (0.5s → 1s → 2s).
    // Aborts immediately if connectivity is lost between attempts.
    private func performWithBackoff(_ work: () async throws -> Void) async throws {
        var delayNs: UInt64 = 500_000_000
        for attempt in 0..<4 {
            do {
                try await work()
                return
            } catch {
                guard isConnected, attempt < 3 else { throw error }
                AppLogger.repository.warning("Action failed, retrying (attempt \(attempt + 1)/3) — \(error, privacy: .public)")
                try? await Task.sleep(nanoseconds: delayNs)
                delayNs *= 2
            }
        }
    }

    // MARK: - Local cache

    private func cachedState() -> UserState {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? decoder.decode(UserState.self, from: data) else {
            return UserState()
        }
        return state
    }

    private func persistState(_ state: UserState) {
        guard let data = try? encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }
}

// Mirrors the server response shape (arrays instead of Sets).
private struct RemoteUserState: Decodable {
    let likedStoryIDs: [String]
    let seenStoryIDs: [String]
}
