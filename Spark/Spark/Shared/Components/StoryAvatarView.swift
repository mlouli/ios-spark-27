import SwiftUI

struct StoryAvatarView: View {
    let user: StoryUser
    let isSeen: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var imageLoadID = UUID()
    @State private var imageLoadFailed = false

    var body: some View {
        VStack(spacing: 6) {
			ZStack {
				Circle()
					.strokeBorder(
						isSeen
						? AnyShapeStyle(Color(.systemGray3))
						: AnyShapeStyle(
							LinearGradient(
								colors: [.orange, .pink, .purple],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						),
						lineWidth: 4
					)
					.frame(width: 94, height: 94)

				AsyncImage(url: user.avatarURL) { phase in
					switch phase {
					case .success(let image):
						image
							.resizable()
							.scaledToFill()

					case .failure:
						Image(systemName: "person.circle.fill")
							.resizable()
							.scaledToFill()
							.foregroundStyle(Color(.systemGray3))
							.onAppear { imageLoadFailed = true }

					default:
						Color(.systemGray5)
					}
				}
				.id(imageLoadID)
				.frame(width: 80, height: 80)
				.clipShape(Circle())
			}
			.saturation(isSeen ? 0.4 : 1.0)

            Text(user.username)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(isSeen ? .secondary : .primary)
        }
        .frame(width: 94)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, imageLoadFailed else { return }
            imageLoadID = UUID()
            imageLoadFailed = false
        }
    }
}

#Preview("Unseen") {
    StoryAvatarView(user: PreviewMocks.user, isSeen: false)
        .padding()
}

#Preview("Seen") {
    StoryAvatarView(user: PreviewMocks.seenUser, isSeen: true)
        .padding()
}
