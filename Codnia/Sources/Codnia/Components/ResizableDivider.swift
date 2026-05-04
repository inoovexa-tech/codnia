import SwiftUI

struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    @State private var dragging = false

    var body: some View {
        Rectangle()
            .foregroundColor(dragging ? Color.accentBlue.opacity(0.8) : Color.clear)
            .frame(width: dragging ? 3 : 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragging = true
                        let delta = value.translation.width
                        let newWidth = width - delta
                        width = min(max(newWidth, min), max)
                    }
                    .onEnded { _ in
                        dragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
