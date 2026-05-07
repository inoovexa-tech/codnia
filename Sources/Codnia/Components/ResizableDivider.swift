import SwiftUI
import AppKit

struct ResizableDivider: NSViewRepresentable {
    @Binding var width: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var side: SidebarSide

    enum SidebarSide {
        case left
        case right
    }

    class Coordinator {
        var widthBinding: Binding<CGFloat>
        var minWidth: CGFloat
        var maxWidth: CGFloat
        var side: SidebarSide
        var lastX: CGFloat = 0
        var isDragging: Bool = false

        init(width: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat, side: SidebarSide) {
            self.widthBinding = width
            self.minWidth = minWidth
            self.maxWidth = maxWidth
            self.side = side
        }

        func beginDrag(at x: CGFloat) {
            lastX = x
            isDragging = true
            NSCursor.resizeLeftRight.push()
        }

        func drag(to x: CGFloat) {
            guard isDragging else { return }
            let delta = x - lastX
            lastX = x
            var newWidth: CGFloat
            if side == .left {
                newWidth = widthBinding.wrappedValue + delta
            } else {
                newWidth = widthBinding.wrappedValue - delta
            }
            newWidth = max(minWidth, min(newWidth, maxWidth))
            widthBinding.wrappedValue = newWidth
        }

        func endDrag() {
            isDragging = false
            NSCursor.pop()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(width: $width, minWidth: minWidth, maxWidth: maxWidth, side: side)
    }

    func makeNSView(context: Context) -> DividerView {
        let view = DividerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: DividerView, context: Context) {
        nsView.coordinator = context.coordinator
    }

    class DividerView: NSView {
        var coordinator: Coordinator?

        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .cursorUpdate]
            addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.resizeLeftRight.set()
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            let isDragging = coordinator?.isDragging ?? false
            let lineX = bounds.midX
            let line = NSBezierPath()
            line.move(to: NSPoint(x: lineX, y: bounds.minY))
            line.line(to: NSPoint(x: lineX, y: bounds.maxY))
            line.lineWidth = 1
            if isDragging {
                NSColor(Color.accentBlue).setStroke()
            } else {
                NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
            }
            line.stroke()
        }

        override func mouseDown(with event: NSEvent) {
            window?.disableCursorRects()
            coordinator?.beginDrag(at: event.locationInWindow.x)
            needsDisplay = true
        }

        override func mouseDragged(with event: NSEvent) {
            coordinator?.drag(to: event.locationInWindow.x)
        }

        override func mouseUp(with event: NSEvent) {
            window?.enableCursorRects()
            window?.resetCursorRects()
            coordinator?.endDrag()
            needsDisplay = true
        }
    }
}
