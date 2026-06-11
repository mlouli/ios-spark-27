import SwiftUI

struct RootView: View {
    @State private var coordinator: AppCoordinator
    @State private var storiesViewModel: StoriesViewModel
    @State private var detailViewModel: StoryDetailViewModel?

    init(coordinator: AppCoordinator) {
        let vm = coordinator.makeStoriesViewModel()
        _coordinator = State(initialValue: coordinator)
        _storiesViewModel = State(initialValue: vm)
    }

    var body: some View {
        ZStack {
            StoriesView(viewModel: storiesViewModel)

            if let vm = detailViewModel {
                StoryDetailView(
                    viewModel: vm,
                    onDismiss: { lastUserID in
                        coordinator.dismissStories()
                        storiesViewModel.scrollToUser(id: lastUserID)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(1)
            }
        }
        .onChange(of: coordinator.storyDetailContext?.id) { _, _ in
            // Explicit, non-bouncing animation scoped to just the presentation
            // change — a bounce overshoots ("up then down"), and an implicit
            // animation on the ZStack sweeps TabView's first layout settle into
            // the same animation, which together cause the entrance jump.
            guard let context = coordinator.storyDetailContext else {
                withAnimation(.easeOut(duration: 0.3)) { detailViewModel = nil }
                return
            }
            let vm = coordinator.makeStoryDetailViewModel(
                context: context,
                loadMore: { await storiesViewModel.loadMore() },
                onStorySeen: { storiesViewModel.markSeen(storyID: $0) },
                onLikeChanged: { storiesViewModel.setLiked(storyID: $0, liked: $1) }
            )
            withAnimation(.easeOut(duration: 0.3)) { detailViewModel = vm }
        }
        .onOpenURL { coordinator.handle(url: $0) }
    }
}

#Preview {
    RootView(coordinator: AppCoordinator(dependencies: MockDependencyContainer(state: PreviewMocks.userState)))
}
