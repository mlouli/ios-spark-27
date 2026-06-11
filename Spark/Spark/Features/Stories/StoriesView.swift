import SwiftUI

struct StoriesView: View {
    @State private var viewModel: StoriesViewModel

    init(viewModel: StoriesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
				VStack {
					storiesRow
					Divider()
					feedPlaceholder
				}
            }
            .navigationTitle("Spark")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.refresh() }
        }
        .task {
            await viewModel.load()
            viewModel.openPendingDeepLink()
        }
    }

    // MARK: - Stories row

    @ViewBuilder
    private var storiesRow: some View {
        if let error = viewModel.error, viewModel.displayedUsers.isEmpty {
            storiesErrorView(error)
        } else if viewModel.isLoading && viewModel.displayedUsers.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 100)
        } else if viewModel.displayedUsers.isEmpty {
            storiesEmptyView
        } else {
            storiesScrollView
        }
    }

    private var storiesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.displayedUsers) { user in
                        StoryAvatarView(user: user, isSeen: viewModel.isSeen(user))
                            .id(user.id)
                            .onTapGesture {
                                if let index = viewModel.displayedUsers.firstIndex(where: { $0.id == user.id }) {
                                    viewModel.selectUser(at: index)
                                }
                            }
                            .onAppear { viewModel.loadNextPageIfNeeded(currentUser: user) }
                    }

					if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: viewModel.scrollTargetUserID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(id, anchor: .center)
                }
                viewModel.clearScrollTarget()
            }
        }
    }

    private var storiesEmptyView: some View {
        VStack(spacing: 4) {
            Text("No stories to show")
                .font(.subheadline).bold()
            Text("Simulation mode · Follow accounts to see their stories here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func storiesErrorView(_ error: Error) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
            Text("Couldn't load stories")
                .font(.subheadline)
            Spacer()
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .frame(height: 120)
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

#Preview("Normal") {
    let coordinator = AppCoordinator(dependencies: MockDependencyContainer(state: PreviewMocks.userState))
    StoriesView(viewModel: coordinator.makeStoriesViewModel())
}

#Preview("Empty (no stories)") {
    let container = MockDependencyContainer(repository: EmptyStoryRepository())
    StoriesView(viewModel: AppCoordinator(dependencies: container).makeStoriesViewModel())
}
