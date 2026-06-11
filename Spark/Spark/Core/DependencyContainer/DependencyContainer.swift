import Foundation

final class DependencyContainer: DependencyContainerProtocol {
    static let shared = DependencyContainer()
    let storyRepository: StoryRepositoryProtocol = {
        if ProcessInfo.processInfo.environment["USE_LOCAL_DATA"] == "1" {
            return LocalStoryRepository()
        }
        return RemoteStoryRepository()
    }()
    private init() {}
}
