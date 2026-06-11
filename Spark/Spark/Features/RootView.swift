import SwiftUI

struct RootView: View {
    @State private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        _coordinator = State(initialValue: coordinator)
    }

    var body: some View {
		NavigationStack {
			let vm = coordinator.makeStoriesViewModel()

			ScrollView {
				VStack {
					StoriesView(viewModel: vm)
					Divider()
					feedPlaceholder
				}
			}
			.overlay {
				if let context = coordinator.storyDetailContext {
					storyDetail(vm, context)
				}
			}
			.navigationTitle("Spark")
			.navigationBarTitleDisplayMode(.inline)
		}
    }

	// MARK: - Story detail

	private func storyDetail(
		_ vm: StoriesViewModel,
		_ context: AppCoordinator.StoryDetailContext
	) -> some View {
		StoryDetailView(
			viewModel: coordinator.makeStoryDetailViewModel(
				context: context,
				loadMore: { await vm.loadMore() },
				onStorySeen: { vm.markSeen(storyID: $0) },
				onLikeChanged: { vm.setLiked(storyID: $0, liked: $1) }
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
