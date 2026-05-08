import SwiftUI
import AppKit

struct HorizontalResizableDivider: View {
    @Binding var height: CGFloat
    var minHeight: CGFloat
    var maxHeight: CGFloat

    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .frame(height: 6)
            .foregroundColor(.clear)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(isDragging ? Color.accentBlue : Color.borderDefault)
            )
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDragging = true
                        let delta = -value.translation.height
                        let newHeight = height + delta
                        height = max(minHeight, min(newHeight, maxHeight))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering && !isDragging {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}