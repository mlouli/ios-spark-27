import SwiftUI

struct RootView: View {
    @State private var coordinator: AppCoordinator
	@State private var storiesViewModel: StoriesViewModel
	@State private var detailViewModel: StoryDetailViewModel?

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
			.refreshable { await storiesViewModel.refresh() }
			.navigationTitle("Spark")
			.navigationBarTitleDisplayMode(.inline)
		}
		.overlay {
			if let detailViewModel {
				storyDetail(detailViewModel)
			}
		}
		// Hands the live instance to the coordinator for scroll-on-dismiss.
		.onAppear { coordinator.storiesViewModel = storiesViewModel }
		// One view model per presentation — creating it inside the overlay
		// closure would allocate a fresh one on every body re-evaluation
		// while the detail is open.
		.onChange(of: coordinator.storyDetailContext?.id) { _, _ in
			guard let context = coordinator.storyDetailContext else {
				detailViewModel = nil
				return
			}
			detailViewModel = coordinator.makeStoryDetailViewModel(
				context: context,
				loadMore: { await storiesViewModel.loadMore() },
				onStorySeen: { storiesViewModel.markSeen(storyID: $0) },
				onLikeChanged: { storiesViewModel.setLiked(storyID: $0, liked: $1) }
			)
		}
    }

	// MARK: - Story detail

	private func storyDetail(_ viewModel: StoryDetailViewModel) -> some View {
		StoryDetailView(
			viewModel: viewModel,
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

#if DEBUG
#Preview {
    RootView(coordinator: AppCoordinator(dependencies: MockDependencyContainer(state: PreviewMocks.userState)))
}
#endif
