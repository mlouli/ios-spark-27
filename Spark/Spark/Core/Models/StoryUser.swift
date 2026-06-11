import Foundation

nonisolated struct StoryUser: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let avatarSeed: String
    let stories: [Story]

    var avatarURL: URL {
        URL(string: "https://picsum.photos/seed/\(avatarSeed)/300/300")!
    }
}
