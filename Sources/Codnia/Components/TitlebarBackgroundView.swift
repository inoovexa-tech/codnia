import SwiftUI
import AppKit

struct InteractiveFrameKey: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func trackInteractiveFrame() -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: InteractiveFrameKey.self,
                        value: [geometry.frame(in: .named("topbar"))]
                    )
            }
        )
    }
}

struct TitlebarBackgroundView: NSViewRepresentable {
    @Binding var interactiveFrames: [CGRect]

    func makeNSView(context: Context) -> TitlebarNSView {
        TitlebarNSView()
    }

    func updateNSView(_ nsView: TitlebarNSView, context: Context) {
        nsView.interactiveFrames = interactiveFrames
    }
}

class TitlebarNSView: NSView {
    var interactiveFrames: [CGRect] = []

    override func hitTest(_ point: NSPoint) -> NSView? {
        let swiftPoint = NSPoint(x: point.x, y: bounds.height - point.y)

        for frame in interactiveFrames {
            if frame.contains(swiftPoint) {
                return nil
            }
        }

        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }

        if event.clickCount == 2 {
            window.performZoom(nil)
        } else {
            window.isMovable = true
            window.performDrag(with: event)
            window.isMovable = false
        }
    }
}
