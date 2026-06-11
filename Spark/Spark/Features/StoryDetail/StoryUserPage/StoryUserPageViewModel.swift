import Foundation
import Observation

@Observable
final class StoryUserPageViewModel {
    private(set) var currentStoryIndex: Int = 0
    private(set) var isLiked: Bool = false
    private(set) var isPaused: Bool = false
    private var likedStoryIDs: Set<String> = []

    let user: StoryUser
    private let repository: StoryRepositoryProtocol
    private let onStorySeen: (String) -> Void
    private let onLikeChanged: (String, Bool) -> Void

    var currentStory: Story { user.stories[currentStoryIndex] }
    var hasNext: Bool { currentStoryIndex < user.stories.count - 1 }
    var hasPrevious: Bool { currentStoryIndex > 0 }

    init(
        user: StoryUser,
        userState: UserState,
        repository: StoryRepositoryProtocol,
        onStorySeen: @escaping (String) -> Void,
        onLikeChanged: @escaping (String, Bool) -> Void = { _, _ in }
    ) {
        precondition(!user.stories.isEmpty, "StoryUserPageViewModel requires at least one story")
        self.user = user
        self.repository = repository
        self.onStorySeen = onStorySeen
        self.onLikeChanged = onLikeChanged
        self.likedStoryIDs = userState.likedStoryIDs
        self.isLiked = userState.likedStoryIDs.contains(user.stories[0].id)
    }

    // MARK: - Navigation

    func goToNext() {
        guard hasNext else { return }
        currentStoryIndex += 1
        isLiked = likedStoryIDs.contains(currentStory.id)
        Task { await markCurrentSeen() }
    }

    func goToPrevious() {
        guard hasPrevious else { return }
        currentStoryIndex -= 1
        isLiked = likedStoryIDs.contains(currentStory.id)
    }

    // MARK: - Actions

    func toggleLike() {
        isLiked.toggle()
        if isLiked {
            likedStoryIDs.insert(currentStory.id)
        } else {
            likedStoryIDs.remove(currentStory.id)
        }
        let storyID = currentStory.id
        let liked = isLiked
        onLikeChanged(storyID, liked)
        Task { await repository.toggleLike(storyID: storyID, isLiked: liked) }
    }

    func markCurrentSeen() async {
        onStorySeen(currentStory.id)
        await repository.markSeen(storyID: currentStory.id)
    }

    func markAllStoriesSeen() async {
        for story in user.stories {
            onStorySeen(story.id)
        }
        // One repository call for the whole set — per-story calls each spawned
        // a state write and a network flush of the entire pending queue.
        await repository.markSeen(storyIDs: user.stories.map(\.id))
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }
}
