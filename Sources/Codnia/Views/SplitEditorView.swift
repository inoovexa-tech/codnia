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

// MARK: - Split Container

struct SplitContainerView: View {
    let container: SplitContainer
    @EnvironmentObject var splitVM: SplitViewModel
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var terminalVM: TerminalViewModel
    @EnvironmentObject var settings: SettingsService

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let isHorizontal = container.direction == .horizontal
            let totalSize = isHorizontal ? geo.size.width : geo.size.height
            let availSize = max(0.0, totalSize - splitDividerThickness)

            let computedFirstSize: CGFloat = {
                if isDragging {
                    let raw = availSize * container.proportion + dragOffset
                    return max(80, min(availSize - 80, raw))
                }
                return max(80, availSize * container.proportion)
            }()

            let secondSize = max(80, totalSize - computedFirstSize - splitDividerThickness)

            if isHorizontal {
                HStack(spacing: 0) {
                    renderNode(container.first)
                        .frame(width: computedFirstSize)

                    DividerView(
                        direction: container.direction,
                        onDragChanged: { delta in
                            isDragging = true
                            dragOffset += delta
                        },
                        onDragEnded: { finalDelta in
                            let newProp = max(0.15, min(0.85, container.proportion + finalDelta / availSize))
                            splitVM.setContainerProportion(container.id, newProp)
                            isDragging = false
                            dragOffset = 0
                        },
                        isDragging: isDragging
                    )
                    .frame(width: splitDividerThickness, height: geo.size.height)

                    renderNode(container.second)
                        .frame(width: secondSize)
                }
            } else {
                VStack(spacing: 0) {
                    renderNode(container.first)
                        .frame(height: computedFirstSize)

                    DividerView(
                        direction: container.direction,
                        onDragChanged: { delta in
                            isDragging = true
                            dragOffset += delta
                        },
                        onDragEnded: { finalDelta in
                            let newProp = max(0.15, min(0.85, container.proportion + finalDelta / availSize))
                            splitVM.setContainerProportion(container.id, newProp)
                            isDragging = false
                            dragOffset = 0
                        },
                        isDragging: isDragging
                    )
                    .frame(width: geo.size.width, height: splitDividerThickness)

                    renderNode(container.second)
                        .frame(height: secondSize)
                }
            }
        }
        .clipped()
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

// MARK: - Divider View

struct DividerView: NSViewRepresentable {
    let direction: SplitDirection
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void
    let isDragging: Bool

    func makeNSView(context: Context) -> DividerNSView {
        let view = DividerNSView()
        view.direction = direction
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: DividerNSView, context: Context) {
        nsView.direction = direction
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
        nsView.needsDisplay = true
    }
}

class DividerNSView: NSView {
    var direction: SplitDirection = .horizontal
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: ((CGFloat) -> Void)?

    private var initialMouseLocation: NSPoint = .zero
    private var currentOffset: CGFloat = 0
    private var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isDragging {
            updateCursor()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            NSCursor.pop()
        }
    }

    private func updateCursor() {
        if direction == .horizontal {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.resizeUpDown.set()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: direction == .horizontal ? .resizeLeftRight : .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
        currentOffset = 0
        isDragging = true
        updateCursor()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentLocation = event.locationInWindow
        var delta: CGFloat = 0

        if direction == .horizontal {
            delta = currentLocation.x - initialMouseLocation.x
            initialMouseLocation.x = currentLocation.x
        } else {
            delta = initialMouseLocation.y - currentLocation.y
            initialMouseLocation.y = currentLocation.y
        }

        currentOffset += delta
        onDragChanged?(delta)
        updateCursor()
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnded?(currentOffset)
        currentOffset = 0
        isDragging = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setFillColor(NSColor.clear.cgColor)
        ctx.fill(bounds)

        ctx.setStrokeColor(NSColor(Color.borderLight).cgColor)
        ctx.setLineWidth(1)

        if direction == .horizontal {
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