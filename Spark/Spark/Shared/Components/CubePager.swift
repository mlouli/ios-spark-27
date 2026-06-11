import SwiftUI

/// Horizontal cube pager with built-in swipe-to-dismiss.
///
/// The pager's drag is attached with `simultaneousGesture`, so it coexists with
/// any gesture inside the page content (tap to navigate, hold to pause, …):
/// the content keeps receiving every touch, while the pager independently
/// tracks movement and drives the cube / dismiss animations. Nothing claims
/// the touch exclusively, so nothing gets swallowed.
///
/// The pager lays out within the safe area; the host view decides what to
/// paint behind the insets.
struct CubePager<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void
    let onNearEnd: () -> Void
    @ViewBuilder let content: (Item, Bool) -> Content

    @State private var dragX: CGFloat = 0
    @State private var dragY: CGFloat = 0
    @State private var dragIntent: DragIntent = .undecided
    @State private var isSnapping = false

    private enum DragIntent { case undecided, horizontal, vertical }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Faces are identified by their item, not their slot: when a page
                // moves from "next" to "current" its view (and @State) survives,
                // and a programmatic index change animates as a real cube roll.
                ForEach(visibleFaces) { face in
                    cubeFace(slot: face.slot, item: face.item, width: w, height: h)
                }
            }
            .offset(y: dismissOffset)
            .scaleEffect(dismissScale)
            // Simultaneous, not exclusive: the page content's own gestures
            // (tap, hold) keep working even though we track the same touches.
            .simultaneousGesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { handleChanged($0, width: w) }
                    .onEnded   { handleEnded($0,   width: w) }
            )
        }
        .onChange(of: currentIndex) { _, index in
            if index >= items.count - 2 { onNearEnd() }
        }
    }

    // MARK: - Cube face

    private struct Face: Identifiable {
        let slot: Int
        let item: Item
        var id: Item.ID { item.id }
    }

    private var visibleFaces: [Face] {
        [-1, 0, 1].compactMap { slot in
            let index = currentIndex + slot
            guard items.indices.contains(index) else { return nil }
            return Face(slot: slot, item: items[index])
        }
    }

    @ViewBuilder
    private func cubeFace(slot: Int, item: Item, width: CGFloat, height: CGFloat) -> some View {
        // pageX: signed distance of this face from the screen centre.
        // angle = pageX / w * 90°, clamped to ±89.9° — exactly ±90° produces a
        // singular projection matrix (edge-on) and renderer warnings.
        let pageX  = CGFloat(slot) * width + dragX
        let degrees = max(-89.9, min(89.9, pageX / width * 90))
        let anchor: UnitPoint = pageX >= 0 ? .leading : .trailing

        Color.black
            .frame(width: width, height: height)
            .overlay { content(item, slot == 0 && !isSnapping) }
            .rotation3DEffect(.degrees(degrees), axis: (0, 1, 0), anchor: anchor, perspective: 2.5)
            .offset(x: pageX)
            .zIndex(zIndex(for: slot))
            .allowsHitTesting(slot == 0)
    }

    // Incoming face sits on top during transition.
    private func zIndex(for slot: Int) -> Double {
        if abs(dragX) < 0.1 { return slot == 0 ? 1 : 0 }
        return (dragX < 0 && slot == 1) || (dragX > 0 && slot == -1) ? 1 : 0
    }

    // Driven by dragY alone (non-zero only during vertical drags) — gating on
    // dragIntent would zero the offset the instant the finger lifts, snapping
    // the card back before the dismiss animation plays.
    private var dismissOffset: CGFloat {
        max(dragY, 0)
    }

    private var dismissScale: CGFloat {
        max(1 - max(dragY, 0) / 1000, 0.9)
    }

    // MARK: - Gesture

    private func handleChanged(_ value: DragGesture.Value, width: CGFloat) {
        guard !isSnapping else { return }

        if dragIntent == .undecided {
            dragIntent = abs(value.translation.width) > abs(value.translation.height)
                ? .horizontal
                : .vertical
        }

        switch dragIntent {
        case .horizontal:
            let atStart = currentIndex == 0               && value.translation.width > 0
            let atEnd   = currentIndex == items.count - 1 && value.translation.width < 0
            dragX = (atStart || atEnd) ? value.translation.width / 3 : value.translation.width
        case .vertical:
            dragY = max(value.translation.height, 0)
        case .undecided:
            break
        }
    }

    private func handleEnded(_ value: DragGesture.Value, width: CGFloat) {
        let intent = dragIntent
        dragIntent = .undecided

        switch intent {
        case .horizontal:
            let dx        = value.translation.width
            let predicted = value.predictedEndTranslation.width
            let goNext = (dx < -width * 0.3 || predicted < -width * 0.5) && currentIndex < items.count - 1
            let goPrev = (dx >  width * 0.3 || predicted >  width * 0.5) && currentIndex > 0

            if goNext {
                snap(to: -width) { currentIndex += 1 }
            } else if goPrev {
                snap(to:  width) { currentIndex -= 1 }
            } else {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) { dragX = 0 }
            }

        case .vertical:
            if value.translation.height > 140
                || value.predictedEndTranslation.height > 500 {
                withAnimation(.easeOut(duration: 0.25)) { dragY = 1000 }
                Task { try? await Task.sleep(for: .seconds(0.25)); onDismiss() }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragY = 0 }
            }

        case .undecided:
            break
        }
    }

    private func snap(to targetX: CGFloat, completion: @escaping () -> Void) {
        isSnapping = true
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            dragX = targetX
        } completion: {
            completion()
            dragX = 0
            isSnapping = false
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewItem: Identifiable {
        let id = UUID()
        let color: Color
        let label: String
    }

    struct Container: View {
        @State private var index = 0
        let items = [
            PreviewItem(color: .red,    label: "Page 1"),
            PreviewItem(color: .green,  label: "Page 2"),
            PreviewItem(color: .blue,   label: "Page 3"),
            PreviewItem(color: .orange, label: "Page 4"),
        ]

        var body: some View {
            CubePager(
                items: items,
                currentIndex: $index,
                onDismiss: { print("dismissed") },
                onNearEnd:  { print("near end")  }
            ) { item, isActive in
                item.color
                    .overlay(
                        VStack {
                            Text(item.label).font(.largeTitle).bold()
                            Text(isActive ? "active" : "inactive").font(.caption)
                        }
                        .foregroundStyle(.white)
                    )
            }
            .background(Color.black.ignoresSafeArea())
        }
    }

    return Container()
}
