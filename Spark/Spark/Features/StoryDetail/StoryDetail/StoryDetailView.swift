import SwiftUI

struct StoryDetailView: View {
    @State private var viewModel: StoryDetailViewModel
    @State private var currentIndex: Int

    private let onDismiss: (String) -> Void

    init(viewModel: StoryDetailViewModel, onDismiss: @escaping (String) -> Void) {
        let vm = viewModel
        _viewModel = State(initialValue: vm)
        let startIndex = vm.users.firstIndex(where: { $0.id == vm.startUserID }) ?? 0
        _currentIndex = State(initialValue: startIndex)
        self.onDismiss = onDismiss
    }

    var body: some View {
        CubePager(
            items: viewModel.users,
            currentIndex: $currentIndex,
            onDismiss: {
                let id = viewModel.users.indices.contains(currentIndex)
                    ? viewModel.users[currentIndex].id
                    : viewModel.startUserID
                onDismiss(id)
            },
            onNearEnd: {
                guard viewModel.users.indices.contains(currentIndex) else { return }
                viewModel.onScrolled(to: viewModel.users[currentIndex].id)
            }
        ) { user, isActive in
            StoryUserPageView(
                viewModel: viewModel.pageViewModel(for: user),
                isActive: isActive,
                onFinished: { advance(from: user.id) },
                onRequestPrevious: { retreat(from: user.id) },
                onDismiss: { onDismiss(user.id) }
            )
        }
        // Pages lay out within the safe area; the insets are painted black.
        .background(Color.black.ignoresSafeArea())
        .onChange(of: currentIndex) { _, index in
            guard viewModel.users.indices.contains(index) else { return }
            viewModel.onScrolled(to: viewModel.users[index].id)
            prefetchNeighbors(at: index)
        }
        .onAppear {
            prefetchNeighbors(at: currentIndex)
            // Stories play hands-free — don't let the screen dim or lock.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func prefetchNeighbors(at index: Int) {
        let neighbors = [index - 1, index + 1]
            .filter { viewModel.users.indices.contains($0) }
            .compactMap { viewModel.users[$0].stories.first?.imageURL }
        StoryImageLoader.shared.prefetch(neighbors)
    }

    private func advance(from id: String) {
        guard let idx = viewModel.users.firstIndex(where: { $0.id == id }) else { return }
        if idx < viewModel.users.count - 1 {
            withAnimation(.easeInOut(duration: 0.35)) { currentIndex = idx + 1 }
        } else {
            onDismiss(id)
        }
    }

    private func retreat(from id: String) {
        guard let idx = viewModel.users.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        withAnimation(.easeInOut(duration: 0.35)) { currentIndex = idx - 1 }
    }
}

#Preview {
    let coordinator = AppCoordinator(dependencies: MockDependencyContainer(state: PreviewMocks.userState))
    let context = AppCoordinator.StoryDetailContext(
        users: [PreviewMocks.user, PreviewMocks.seenUser],
        startIndex: 0,
        userState: PreviewMocks.userState
    )
    StoryDetailView(
        viewModel: coordinator.makeStoryDetailViewModel(
            context: context,
            loadMore: { [PreviewMocks.user, PreviewMocks.seenUser] } as () async -> [StoryUser],
            onStorySeen: { _ in }
        ),
        onDismiss: { _ in }
    )
}
