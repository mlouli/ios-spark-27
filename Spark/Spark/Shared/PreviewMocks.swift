import Foundation

enum PreviewMocks {
    static let story1 = Story(
        id: "preview_story_1",
        imageSeed: "mountain_dawn",
        caption: "First light on the peaks 🏔️",
        timestamp: Date()
    )

    static let story2 = Story(
        id: "preview_story_2",
        imageSeed: "forest_mist",
        caption: "Lost in the woods 🌲",
        timestamp: Date().addingTimeInterval(-3600)
    )

    static let user = StoryUser(
        id: "preview_user_1",
        username: "aurora.wild",
        avatarSeed: "aurora_wild",
        stories: [story1, story2]
    )

    static let seenUser = StoryUser(
        id: "preview_user_2",
        username: "leo.frames",
        avatarSeed: "leo_frames",
        stories: [story1]
    )

    static var userState: UserState {
        var state = UserState()
        state.likedStoryIDs = [story1.id]
        // story1 is the only story on seenUser → allSatisfy passes → ring shows as seen.
        // user has [story1, story2] so allSatisfy fails → ring shows as unseen.
        state.seenStoryIDs = [story1.id]
        return state
    }
}
