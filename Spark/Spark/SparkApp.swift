import SwiftUI

@main
struct SparkApp: App {
    @State private var coordinator = AppCoordinator(dependencies: DependencyContainer.shared)

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
        }
    }
}
