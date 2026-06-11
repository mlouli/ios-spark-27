import SwiftUI

struct StoryUserPageView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: StoryUserPageViewModel
    @State private var timerProgress: CGFloat = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var pressStart: Date?

    let isActive: Bool
    let onFinished: () -> Void
    let onRequestPrevious: () -> Void
    let onDismiss: () -> Void

    private let storyDuration: TimeInterval = 7

    init(
        viewModel: StoryUserPageViewModel,
        isActive: Bool,
        onFinished: @escaping () -> Void,
        onRequestPrevious: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.isActive = isActive
        self.onFinished = onFinished
        self.onRequestPrevious = onRequestPrevious
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Image card ──────────────────────────────────────────────
                ZStack(alignment: .top) {
                    // Gesture lives on the image only — the top bar's buttons
                    // (close, …) own their touches, and CubePager owns the
                    // horizontal and vertical swipes.
                    storyImage
                        .simultaneousGesture(cardGesture(in: geo))
                    topGradient
                    topBar
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Below the card ──────────────────────────────────────────
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.black)
        .onAppear { if isActive { activate() } }
        .onChange(of: isActive) { _, active in
            active ? activate() : deactivate()
        }
        .onChange(of: scenePhase) { _, phase in
            guard isActive else { return }
            if phase == .background {
                timerTask?.cancel()
            } else if phase == .active {
                startTimer(from: timerProgress)
            }
        }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Subviews

    private var storyImage: some View {
        CachedStoryImage(url: viewModel.currentStory.imageURL)
    }

    private var topGradient: some View {
        LinearGradient(
            colors: [.black.opacity(0.5), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 120)
        .frame(maxHeight: .infinity, alignment: .top)
        // Purely decorative — must not swallow taps meant for the image below.
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            StoryProgressBar(
                count: viewModel.user.stories.count,
                currentIndex: viewModel.currentStoryIndex,
                progress: timerProgress
            )

            HStack(spacing: 10) {
                AsyncImage(url: viewModel.user.avatarURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color(.systemGray4))
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.user.username)
                        .font(.subheadline).bold()
                        .foregroundStyle(.white)
                    Text(viewModel.currentStory.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Text(viewModel.currentStory.caption)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

			Button {
				UISelectionFeedbackGenerator().selectionChanged()
				viewModel.toggleLike()
			} label: {
                Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(viewModel.isLiked ? .red : .white)
                    .padding(8)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }

    // MARK: - Gestures

    /// Handles tap and press-and-hold for the image card.
    /// CubePager (the parent) owns horizontal swipes (cube transition) and
    /// vertical swipes (dismiss), so this gesture only needs to cover tap and hold.
    private func cardGesture(in geo: GeometryProxy) -> some Gesture {
        let cardMidX = (geo.size.width - 24) / 2
        return DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if pressStart == nil {
                    pressStart = Date()
                    viewModel.pause()
                }
            }
            .onEnded { value in
                let held = pressStart.map { Date().timeIntervalSince($0) } ?? 0
                pressStart = nil
                viewModel.resume()
                let moved = abs(value.translation.width) > 10 || abs(value.translation.height) > 10
                if !moved && held < 0.3 {
                    if value.location.x < cardMidX { handlePrevious() } else { handleNext() }
                }
            }
    }

    // MARK: - Activation

    private func activate() {
        prefetchUpcoming()
        Task { await viewModel.markAllStoriesSeen() }
        startTimer()
    }

    /// Warms the next few images so tapping forward is an instant swap.
    private func prefetchUpcoming() {
        let stories = viewModel.user.stories
        let start = viewModel.currentStoryIndex
        let end = min(start + 3, stories.count)
        StoryImageLoader.shared.prefetch(stories[start..<end].map(\.imageURL))
    }

    private func deactivate() {
        timerTask?.cancel()
        timerProgress = 0
        viewModel.resume()
    }

    // MARK: - Timer

    private func startTimer(from startProgress: CGFloat = 0) {
        timerTask?.cancel()
        timerProgress = startProgress

        timerTask = Task { @MainActor in
            let tickInterval: TimeInterval = 0.05
            let remainingTicks = Int((1.0 - startProgress) * CGFloat(storyDuration / tickInterval))

            for _ in 0..<remainingTicks {
                while viewModel.isPaused {
                    try? await Task.sleep(for: .seconds(tickInterval))
                    if Task.isCancelled { return }
                }
                try? await Task.sleep(for: .seconds(tickInterval))
                if Task.isCancelled { return }
                timerProgress += CGFloat(tickInterval / storyDuration)
            }

            handleNext()
        }
    }

    private func handleNext() {
        if viewModel.hasNext {
            viewModel.goToNext()
            prefetchUpcoming()
            startTimer()
        } else {
            timerTask?.cancel()
            onFinished()
        }
    }

    private func handlePrevious() {
        if viewModel.hasPrevious {
            viewModel.goToPrevious()
            startTimer()
        } else {
            onRequestPrevious()
        }
    }
}

#Preview {
    let coordinator = AppCoordinator(dependencies: MockDependencyContainer(state: PreviewMocks.userState))
    let context = AppCoordinator.StoryDetailContext(
        users: [PreviewMocks.user],
        startIndex: 0,
        userState: PreviewMocks.userState
    )
    let detailVM = coordinator.makeStoryDetailViewModel(
        context: context,
        loadMore: { [PreviewMocks.user] } as () async -> [StoryUser],
        onStorySeen: { _ in }
    )
    StoryUserPageView(
        viewModel: detailVM.pageViewModel(for: PreviewMocks.user),
        isActive: true,
        onFinished: {},
        onRequestPrevious: {},
        onDismiss: {}
    )
}
