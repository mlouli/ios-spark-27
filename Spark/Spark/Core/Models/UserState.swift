import Foundation

/// Local mirror of server-side user interaction state.
/// Acts as a cache that gets overwritten on successful server fetch,
/// and accumulates pending actions while offline.
nonisolated struct UserState: Codable {
    var likedStoryIDs: Set<String>
    var seenStoryIDs: Set<String>
    var pendingActions: [PendingAction]

    init() {
        likedStoryIDs = []
        seenStoryIDs = []
        pendingActions = []
    }
}

nonisolated struct PendingAction: Codable, Identifiable {
    enum ActionType: String, Codable {
        case like, unlike, seen
    }

    let id: String
    let storyID: String
    let type: ActionType
    let createdAt: Date

    init(storyID: String, type: ActionType) {
        self.id = UUID().uuidString
        self.storyID = storyID
        self.type = type
        self.createdAt = Date()
    }
}
