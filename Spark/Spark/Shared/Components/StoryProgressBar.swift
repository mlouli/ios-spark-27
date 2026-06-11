import SwiftUI

struct StoryProgressBar: View {
    let count: Int
    let currentIndex: Int
    let progress: CGFloat // 0..1 for the active segment

    private let spacing: CGFloat = 4
    private let height: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { i in
                segment(at: i)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.linear(duration: 0.1), value: progress)
    }

    private func segment(at index: Int) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * segmentFill(for: index))
                }
            }
    }

    private func segmentFill(for index: Int) -> CGFloat {
        if index < currentIndex { return 1 }
        if index == currentIndex { return progress }
        return 0
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StoryProgressBar(count: 3, currentIndex: 1, progress: 0.6)
            .padding()
    }
}
