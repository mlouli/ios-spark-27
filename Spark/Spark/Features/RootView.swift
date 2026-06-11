import SwiftUI

struct RootView: View {
    @State private var coordinator: AppCoordinator
	@State private var storiesViewModel: StoriesViewModel

    init(coordinator: AppCoordinator) {
        _coordinator = State(initialValue: coordinator)
		_storiesViewModel = State(initialValue: coordinator.makeStoriesViewModel())
    }

    var body: some View {
		NavigationStack {
			ScrollView {
				VStack {
					StoriesView(viewModel: storiesViewModel)
					Divider()
					feedPlaceholder
				}
			}
			.navigationTitle("Spark")
			.navigationBarTitleDisplayMode(.inline)
		}
		.overlay {
			if let context = coordinator.storyDetailContext {
				storyDetail(context)
			}
		}
		// Hands the live instance to the coordinator for scroll-on-dismiss.
		.onAppear { coordinator.storiesViewModel = storiesViewModel }
    }

	// MARK: - Story detail

	private func storyDetail(_ context: AppCoordinator.StoryDetailContext) -> some View {
		StoryDetailView(
			viewModel: coordinator.makeStoryDetailViewModel(
				context: context,
				loadMore: { await storiesViewModel.loadMore() },
				onStorySeen: { storiesViewModel.markSeen(storyID: $0) },
				onLikeChanged: { storiesViewModel.setLiked(storyID: $0, liked: $1) }
			),
			onDismiss: { lastUserID in
				coordinator.dismissStories(lastUserID: lastUserID)
			}
		)
		.transition(.asymmetric(
			insertion: .move(edge: .bottom).combined(with: .opacity),
			removal: .opacity
		))
		.zIndex(1)
	}

	// MARK: - Feed placeholder

	private var feedPlaceholder: some View {
		VStack(spacing: 16) {
			ForEach(0..<6, id: \.self) { _ in
				RoundedRectangle(cornerRadius: 12)
					.fill(Color(.systemGray6))
					.frame(maxWidth: .infinity)
					.frame(height: 300)
					.padding(.horizontal, 16)
			}
		}
		.padding(.top, 12)
	}
}

#Preview {
    RootView(coordinator: AppCoordinator(dependencies: MockDependencyContainer(state: PreviewMocks.userState)))
}
