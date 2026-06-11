import SwiftUI

/// In-memory cache of decoded story images plus a prefetcher.
/// Decoding is done off the main thread via `byPreparingForDisplay()`, so once
/// an image is cached, landing on its story is an instant, synchronous render
/// with no placeholder flash and no decode hitch — the key to smooth, rapid
/// tapping through stories.
@MainActor
final class StoryImageLoader {
    static let shared = StoryImageLoader()
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: Set<URL> = []

    private init() {
        cache.countLimit = 40
    }

    /// Synchronous lookup. Non-nil when the decoded image is already in memory,
    /// letting the view render it in the same frame.
    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Returns a display-ready image, fetching and decoding if necessary.
    func loadImage(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        let prepared = await image.byPreparingForDisplay() ?? image
        cache.setObject(prepared, forKey: url as NSURL)
        return prepared
    }

    /// Warms the cache for upcoming stories so taps land instantly.
    /// De-duplicates in-flight requests.
    func prefetch(_ urls: [URL]) {
        for url in urls {
            guard cache.object(forKey: url as NSURL) == nil else { continue }
            guard !inFlight.contains(url) else { continue }
            inFlight.insert(url)
            
            Task {
                _ = await loadImage(for: url)
                markComplete(url)
            }
        }
    }
    
    private func markComplete(_ url: URL) {
        inFlight.remove(url)
    }
}

/// Renders a story image with an instant in-memory path and graceful
/// loading / failure states. Backed by `StoryImageLoader`.
struct CachedStoryImage: View {
    @Environment(\.scenePhase) private var scenePhase
    let url: URL

    @State private var image: UIImage?
    @State private var didFail = false
    @State private var retryToken = 0

    var body: some View {
        Color.black.overlay {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didFail {
                Button {
                    didFail = false
                    retryToken += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white)
                        .font(.largeTitle)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // Re-runs (cancelling the prior load) whenever the URL or retry token
        // changes. The synchronous cache hit below renders in the same frame.
        .task(id: "\(url.absoluteString)#\(retryToken)") {
            if let cached = StoryImageLoader.shared.cachedImage(for: url) {
                image = cached
                didFail = false
                return
            }
            image = nil
            didFail = false
            let loaded = await StoryImageLoader.shared.loadImage(for: url)
            guard !Task.isCancelled else { return }
            if let loaded {
                image = loaded
            } else {
                didFail = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && didFail {
                didFail = false
                retryToken += 1
            }
        }
    }
}
