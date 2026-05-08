import SwiftUI
import AppKit

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }

    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

final class WindowDragNSView: NSView {
    private var initialMouseLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.performZoom(nil)
            return
        }

        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window,
              let initialMouse = initialMouseLocation,
              let initialOrigin = initialWindowOrigin else { return }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - initialMouse.x
        let deltaY = currentMouse.y - initialMouse.y

        let newOrigin = NSPoint(
            x: initialOrigin.x + deltaX,
            y: initialOrigin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        initialMouseLocation = nil
        initialWindowOrigin = nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

struct TopbarFreeArea: NSViewRepresentable {
    func makeNSView(context: Context) -> TopbarFreeAreaNSView {
        TopbarFreeAreaNSView()
    }

    func updateNSView(_ nsView: TopbarFreeAreaNSView, context: Context) {}
}

final class TopbarFreeAreaNSView: NSView {
    private var initialMouseLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.performZoom(nil)
            return
        }

        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window,
              let initialMouse = initialMouseLocation,
              let initialOrigin = initialWindowOrigin else { return }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - initialMouse.x
        let deltaY = currentMouse.y - initialMouse.y

        let newOrigin = NSPoint(
            x: initialOrigin.x + deltaX,
            y: initialOrigin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        initialMouseLocation = nil
        initialWindowOrigin = nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}