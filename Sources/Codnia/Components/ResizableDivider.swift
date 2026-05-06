import SwiftUI
import AppKit

struct ResizableDivider: NSViewRepresentable {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let side: SidebarSide

    enum SidebarSide {
        case left
        case right
    }

    func makeNSView(context: Context) -> DividerView {
        let view = DividerView()
        view.side = side
        view.onResize = { [width] delta in
            let newWidth = width - delta
            self.width = Swift.min(Swift.max(newWidth, minWidth), maxWidth)
        }
        return view
    }

    func updateNSView(_ nsView: DividerView, context: Context) {}

    class DividerView: NSView {
        var side: SidebarSide = .right
        var onResize: ((CGFloat) -> Void)?
        private var dragging = false
        private var startX: CGFloat = 0

        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas { removeTrackingArea(area) }
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseEnteredAndExited, .cursorUpdate],
                owner: self,
                userInfo: nil
            ))
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.resizeLeftRight.set()
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            let lineX = bounds.midX
            let line = NSBezierPath()
            line.move(to: NSPoint(x: lineX, y: bounds.minY))
            line.line(to: NSPoint(x: lineX, y: bounds.maxY))
            line.lineWidth = 1

            if dragging {
                NSColor(Color.accentBlue).setStroke()
            } else {
                NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
            }
            line.stroke()
        }

        override func mouseDown(with event: NSEvent) {
            dragging = true
            startX = event.locationInWindow.x
            window?.disableCursorRects()
            NSCursor.resizeLeftRight.set()
            needsDisplay = true
        }

        override func mouseDragged(with event: NSEvent) {
            guard dragging else { return }
            let currentX = event.locationInWindow.x
            let delta = currentX - startX
            onResize?(delta)
        }

        override func mouseUp(with event: NSEvent) {
            dragging = false
            window?.enableCursorRects()
            window?.resetCursorRects()
            needsDisplay = true
        }
    }
}
