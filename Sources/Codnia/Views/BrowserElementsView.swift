import SwiftUI

struct BrowserElementsView: View {
    @ObservedObject var devToolsService: BrowserDevToolsService
    @State private var splitRatio: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if devToolsService.isDOMLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .textSecondary))
                Spacer()
            } else if let tree = devToolsService.domTree {
                HSplitView {
                    domTreePanel(tree)
                    if devToolsService.selectedDOMNodeId != nil {
                        stylesPanel
                            .frame(minWidth: 200)
                    }
                }
                .background(Color.bgPrimary)
            } else {
                emptyState
            }
        }
        .onChange(of: devToolsService.selectedDOMNodeId) { _ in
            if devToolsService.selectedDOMNodeId != nil {
                devToolsService.refreshStylesForSelected()
            }
        }
    }

    private func findNode(id: UUID, in node: BrowserDOMNode) -> BrowserDOMNode? {
        if node.id == id { return node }
        for child in node.children {
            if let found = findNode(id: id, in: child) { return found }
        }
        return nil
    }

    @ViewBuilder
    private func domTreePanel(_ tree: BrowserDOMNode) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    DOMNodeRow(node: tree, depth: 0, devToolsService: devToolsService)
                }
            }
            .background(Color.bgPrimary)

            if let selectedId = devToolsService.selectedDOMNodeId,
               let selected = findNode(id: selectedId, in: tree) {
                elementDetailPanel(selected)
            }
        }
        .frame(minWidth: 200)
        .layoutPriority(1)
    }

    @ViewBuilder
    private var stylesPanel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $devToolsService.selectedTab) {
                Text("Styles").tag(BrowserDevToolsService.DevToolsTab.styles)
                Text("Computed").tag(BrowserDevToolsService.DevToolsTab.computed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if devToolsService.selectedTab == .styles {
                BrowserStylesView(devToolsService: devToolsService)
            } else {
                BrowserComputedView(devToolsService: devToolsService)
            }
        }
        .background(Color.bgPrimary)
    }

    @State private var editingAttrName: String? = nil
    @State private var editingAttrValue: String = ""

    @ViewBuilder
    private func elementDetailPanel(_ node: BrowserDOMNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Element Info")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Button(action: { devToolsService.selectedDOMNodeId = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .frame(width: 14, height: 14)
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.bgSecondary)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 3) {
                    infoLine(label: "Tag", value: "<\(node.tag)>")
                    if !node.nodeId.isEmpty {
                        infoLine(label: "ID", value: "#\(node.nodeId)")
                    }
                    if !node.classes.isEmpty {
                        infoLine(label: "Class", value: node.classes)
                    }

                    if !node.attributes.isEmpty {
                        Text("Attributes")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                        ForEach(Array(node.attributes.keys.sorted()), id: \.self) { key in
                            HStack(alignment: .top, spacing: 6) {
                                Text(key)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.accentBlue)
                                    .frame(width: 80, alignment: .trailing)
                                if editingAttrName == key {
                                    TextField("Value", text: $editingAttrValue)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(.textPrimary)
                                        .onSubmit {
                                            let selector = node.nodeId.isEmpty ? node.tag : "#\(node.nodeId)"
                                            devToolsService.setAttribute(selector: selector, name: key, value: editingAttrValue)
                                            editingAttrName = nil
                                        }
                                } else {
                                    Text(node.attributes[key] ?? "")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(.textPrimary)
                                        .textSelection(.enabled)
                                        .lineLimit(3)
                                        .onTapGesture(count: 2) {
                                            editingAttrName = key
                                            editingAttrValue = node.attributes[key] ?? ""
                                        }
                                }
                            }
                        }
                    }

                    if let text = node.attributes["innerText"], !text.isEmpty {
                        Text("Text Content")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                        Text(text.prefix(500))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.textTertiary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 160)
        }
        .background(Color.bgPrimary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
    }

    private func infoLine(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 40, alignment: .trailing)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.accentBlue)
                .textSelection(.enabled)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            Text("Elements")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
            Button(action: { devToolsService.toggleInspectMode() }) {
                Image(systemName: "cursor.rays")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(devToolsService.isInspecting ? .accentBlue : .textTertiary)
            .help(devToolsService.isInspecting ? "Stop inspecting" : "Inspect element in page")

            Button(action: { devToolsService.refreshDOM() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.textTertiary)
            .help("Refresh DOM tree")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(devToolsService.isInspecting ? Color.accentBlue.opacity(0.08) : Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 20))
                .foregroundColor(.textTertiary)
            Text("Load the DOM tree")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
            Button("Refresh") { devToolsService.refreshDOM() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DOMNodeRow: View {
    let node: BrowserDOMNode
    let depth: Int
    let devToolsService: BrowserDevToolsService

    @State private var isExpanded: Bool = false

    private let baseIndent: CGFloat = 12

    private var isSelected: Bool {
        devToolsService.selectedDOMNodeId == node.id
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if !node.children.isEmpty {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isExpanded.toggle()
                    }
                }
                if node.tag != "#text" {
                    devToolsService.selectedDOMNodeId = node.id
                    devToolsService.highlightElement(node)
                    let selector = node.nodeId.isEmpty ? node.tag : "#\(node.nodeId)"
                    devToolsService.selectedElementSelector = selector
                }
            }) {
                HStack(spacing: 3) {
                    ForEach(0..<depth, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.borderDefault.opacity(0.3))
                            .frame(width: baseIndent)
                    }

                    if !node.children.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 10)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 10)
                    }

                    tagBadge
                }
                .padding(.vertical, 2)
                .padding(.trailing, 4)
                .background(isSelected ? Color.accentBlue.opacity(0.18) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .id(node.id)

            if isExpanded && !node.children.isEmpty {
                ForEach(node.children) { child in
                    DOMNodeRow(node: child, depth: depth + 1, devToolsService: devToolsService)
                }
            }
        }
        .onAppear {
            isExpanded = node.isExpanded
        }
    }

    @ViewBuilder
    private var tagBadge: some View {
        if node.tag == "#text" {
            Text(truncatedText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textTertiary)
                .lineLimit(1)
        } else {
            Text("<")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textTertiary)
            +
            Text(node.tag)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.accentBlue)
            +
            Text(nodeDisplaySuffix)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textTertiary)
            +
            Text(">")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textTertiary)
        }
    }

    private var nodeDisplaySuffix: String {
        var suffix = ""
        if !node.nodeId.isEmpty {
            suffix += "#\(node.nodeId)"
        }
        if !node.classes.isEmpty {
            let clsParts = node.classes.split(separator: " ").prefix(3)
            suffix += clsParts.map { ".\($0)" }.joined()
        }
        return suffix
    }

    private var truncatedText: String {
        let text = node.attributes["text"] ?? ""
        if text.count > 80 {
            return String(text.prefix(80)) + "..."
        }
        return text
    }
}
