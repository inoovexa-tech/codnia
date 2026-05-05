import SwiftUI

struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    @State private var dragging = false

    var body: some View {
        Rectangle()
            .frame(width: 4)
            .foregroundColor(dragging ? Color.accentBlue : Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragging = true
                        let newWidth = width - value.translation.width
                        width = Swift.min(Swift.max(newWidth, minWidth), maxWidth)
                    }
                    .onEnded { _ in
                        dragging = false
                    }
            )
    }
}
