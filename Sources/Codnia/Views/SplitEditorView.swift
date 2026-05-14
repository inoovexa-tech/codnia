import SwiftUI

let splitDividerThickness: CGFloat = 5

struct SplitEditorView: View {
    @EnvironmentObject var splitVM: SplitViewModel
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    @State private var inFileSearchQuery: String = ""
    @State private var inFileSearchResults: [NSRange] = []
    @State private var inFileSearchCurrentIndex: Int = 0
    @FocusState private var inFileSearchFocused: Bool

    var body: some View {
        ZStack {
            renderPane(splitVM.root)

            if editorVM.showInFileSearch {
                inFileSearchOverlay
            }

            if let activeTab = editorVM.currentTab,
               activeTab.type == .file,
               editorVM.isCurrentTabMarkdown {
                VStack {
                    HStack {
                        Spacer()
                        markdownToggleButton
                            .padding(.trailing, 20)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .onChange(of: editorVM.activeTabId) { newTabId in
            splitVM.setActivePaneTab(newTabId)
        }
        .onAppear {
            let ids = splitVM.root.allLeafIds
            if let firstId = ids.first {
                splitVM.activePaneId = firstId
                if let tabId = editorVM.activeTabId {
                    splitVM.root.mutateLeaf(id: firstId) { leaf in
                        leaf.tabId = tabId
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderPane(_ pane: SplitPane) -> some View {
        switch pane {
        case .leaf(let leaf):
            EditorPaneView(leaf: leaf)

        case .split(let container):
            SplitContainerView(container: container)
        }
    }

    private var markdownToggleButton: some View {
        HStack(spacing: 4) {
            Image(systemName: editorVM.showMarkdownPreview ? "doc.plaintext" : "eye")
                .font(.system(size: 11, weight: .medium))
            Text(editorVM.showMarkdownPreview ? "Code" : "Preview")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.bgTertiary.opacity(0.6))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.borderLight.opacity(0.5), lineWidth: 0.5)
        )
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                editorVM.showMarkdownPreview.toggle()
            }
        }
        .help(editorVM.showMarkdownPreview ? "Show code editor" : "Show markdown preview")
    }

    private var inFileSearchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)

                TextField("Find in file", text: $inFileSearchQuery)
                    .font(.system(size: 12))
                    .foregroundColor(.textPrimary)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 200)
                    .focused($inFileSearchFocused)
                    .onAppear { inFileSearchFocused = true }
                    .onSubmit {
                        if inFileSearchResults.count > 1 {
                            performInFileSearchNext()
                        } else {
                            performInFileSearch()
                        }
                    }
                    .onChange(of: inFileSearchQuery) { _ in performInFileSearch() }

                if !inFileSearchQuery.isEmpty {
                    Text("\(inFileSearchResults.isEmpty ? 0 : inFileSearchCurrentIndex + 1)/\(inFileSearchResults.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }

                Button(action: performInFileSearchPrevious) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(inFileSearchResults.isEmpty)

                Button(action: performInFileSearchNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(inFileSearchResults.isEmpty)

                Button(action: {
                    editorVM.showInFileSearch = false
                    inFileSearchQuery = ""
                    inFileSearchResults = []
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bgSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderLight, lineWidth: 0.5)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func performInFileSearch() {
        guard !inFileSearchQuery.isEmpty else {
            inFileSearchResults = []
            return
        }
        let content = editorVM.editorContent as NSString
        var ranges: [NSRange] = []
        let searchRange = NSRange(location: 0, length: content.length)
        content.enumerateSubstrings(in: searchRange, options: .byLines) { substring, lineRange, _, _ in
            if let line = substring {
                var searchStart = 0
                while searchStart < line.count {
                    let range = (line as NSString).range(of: self.inFileSearchQuery, options: .caseInsensitive, range: NSRange(location: searchStart, length: line.count - searchStart))
                    if range.location == NSNotFound { break }
                    let fullRange = NSRange(location: lineRange.location + range.location, length: range.length)
                    ranges.append(fullRange)
                    searchStart = lineRange.location + range.location + range.length
                }
            }
        }
        inFileSearchResults = ranges
        inFileSearchCurrentIndex = ranges.isEmpty ? 0 : 0
    }

    private func performInFileSearchNext() {
        guard !inFileSearchResults.isEmpty else { return }
        inFileSearchCurrentIndex = (inFileSearchCurrentIndex + 1) % inFileSearchResults.count
    }

    private func performInFileSearchPrevious() {
        guard !inFileSearchResults.isEmpty else { return }
        inFileSearchCurrentIndex = inFileSearchCurrentIndex == 0 ? inFileSearchResults.count - 1 : inFileSearchCurrentIndex - 1
    }
}

// MARK: - Split Container (custom layout with visible divider)

struct SplitContainerView: View {
    let container: SplitContainer
    @EnvironmentObject var splitVM: SplitViewModel
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if container.direction == .horizontal {
                    horizontalContent(geo: geo)
                } else {
                    verticalContent(geo: geo)
                }

                SplitDividerNSView(
                    direction: container.direction,
                    dividerPosition: dividerPosition(geo: geo),
                    thickness: splitDividerThickness,
                    isHorizontal: container.direction == .horizontal,
                    onDragChanged: { delta in
                        isDragging = true
                        dragOffset = delta
                    },
                    onDragEnded: { delta in
                        let total = axisSize(geo: geo)
                        let avail = total - splitDividerThickness
                        if avail > 0 {
                            let newProp = max(0.15, min(0.85, container.proportion + delta / avail))
                            splitVM.setContainerProportion(container.id, newProp)
                        }
                        isDragging = false
                        dragOffset = 0
                    },
                    onHoverEnter: {
                        container.direction == .horizontal
                            ? NSCursor.resizeLeftRight.push()
                            : NSCursor.resizeUpDown.push()
                    },
                    onHoverExit: {
                        NSCursor.pop()
                    }
                )
                .frame(
                    width: container.direction == .horizontal ? splitDividerThickness + 4 : nil,
                    height: container.direction == .vertical ? splitDividerThickness + 4 : nil
                )
                .offset(
                    x: container.direction == .horizontal ? dividerPosition(geo: geo) - 2 : 0,
                    y: container.direction == .vertical ? dividerPosition(geo: geo) - 2 : 0
                )
            }
            .clipped()
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func horizontalContent(geo: GeometryProxy) -> some View {
        let firstW = max(80, paneWidth(geo: geo))
        let secondW = max(80, otherWidth(geo: geo))

        return HStack(spacing: 0) {
            renderNode(container.first)
                .frame(width: firstW)
            Color.clear
                .frame(width: splitDividerThickness)
            renderNode(container.second)
                .frame(width: max(80, secondW))
        }
    }

    private func verticalContent(geo: GeometryProxy) -> some View {
        let firstH = max(80, paneWidth(geo: geo))
        let secondH = max(80, otherWidth(geo: geo))

        return VStack(spacing: 0) {
            renderNode(container.first)
                .frame(height: firstH)
            Color.clear
                .frame(height: splitDividerThickness)
            renderNode(container.second)
                .frame(height: max(80, secondH))
        }
    }

    // MARK: Geometry helpers

    private func axisSize(geo: GeometryProxy) -> CGFloat {
        container.direction == .horizontal ? geo.size.width : geo.size.height
    }

    private func availSize(geo: GeometryProxy) -> CGFloat {
        max(0, axisSize(geo: geo) - splitDividerThickness)
    }

    private func effectiveProportion(geo: GeometryProxy) -> CGFloat {
        let avail = availSize(geo: geo)
        guard avail > 0 else { return container.proportion }
        let raw = container.proportion + (isDragging ? dragOffset / avail : 0)
        return max(0.15, min(0.85, raw))
    }

    private func paneWidth(geo: GeometryProxy) -> CGFloat {
        availSize(geo: geo) * effectiveProportion(geo: geo)
    }

    private func otherWidth(geo: GeometryProxy) -> CGFloat {
        axisSize(geo: geo) - paneWidth(geo: geo) - splitDividerThickness
    }

    private func dividerPosition(geo: GeometryProxy) -> CGFloat {
        paneWidth(geo: geo) + (isDragging ? dragOffset * 0 : 0)
    }

    @ViewBuilder
    private func renderNode(_ pane: SplitPane) -> some View {
        switch pane {
        case .leaf(let leaf):
            EditorPaneView(leaf: leaf)
        case .split(let container):
            SplitContainerView(container: container)
        }
    }
}

// MARK: - Split Divider (NSViewRepresentable for reliable mouse tracking)

struct SplitDividerNSView: NSViewRepresentable {
    let direction: SplitDirection
    let dividerPosition: CGFloat
    let thickness: CGFloat
    let isHorizontal: Bool
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void
    let onHoverEnter: () -> Void
    let onHoverExit: () -> Void

    func makeNSView(context: Context) -> SplitDividerContainerView {
        let v = SplitDividerContainerView()
        v.isHorizontal = isHorizontal
        v.direction = direction
        v.onDragChanged = onDragChanged
        v.onDragEnded = onDragEnded
        v.onHoverEnter = onHoverEnter
        v.onHoverExit = onHoverExit
        v.wantsLayer = true
        return v
    }

    func updateNSView(_ nsView: SplitDividerContainerView, context: Context) {
        nsView.isHorizontal = isHorizontal
        nsView.direction = direction
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
        nsView.onHoverEnter = onHoverEnter
        nsView.onHoverExit = onHoverExit
        nsView.needsDisplay = true
    }
}

class SplitDividerContainerView: NSView {
    var isHorizontal: Bool = true
    var direction: SplitDirection = .horizontal
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: ((CGFloat) -> Void)?
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var dragStartPoint: CGPoint = .zero

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingArea()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }

    private func updateTrackingArea() {
        if let old = trackingArea {
            removeTrackingArea(old)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        onHoverEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        onHoverExit?()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        let delta = isHorizontal
            ? current.x - dragStartPoint.x
            : current.y - dragStartPoint.y
        onDragChanged?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        let delta = isHorizontal
            ? current.x - dragStartPoint.x
            : current.y - dragStartPoint.y
        onDragEnded?(delta)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Clear background
        ctx.setFillColor(NSColor.clear.cgColor)
        ctx.fill(bounds)

        // Draw the visible line
        ctx.setStrokeColor(NSColor(Color.borderLight).cgColor)
        ctx.setLineWidth(1)

        if isHorizontal {
            let x = bounds.midX
            ctx.move(to: CGPoint(x: x, y: bounds.minY))
            ctx.addLine(to: CGPoint(x: x, y: bounds.maxY))
        } else {
            let y = bounds.midY
            ctx.move(to: CGPoint(x: bounds.minX, y: y))
            ctx.addLine(to: CGPoint(x: bounds.maxX, y: y))
        }
        ctx.strokePath()
    }
}
