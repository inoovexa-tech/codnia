import Foundation

struct BrowserDOMNode: Identifiable, Equatable {
    let id: UUID
    let tag: String
    let nodeId: String
    let classes: String
    let attributes: [String: String]
    var children: [BrowserDOMNode]
    var isExpanded: Bool
    var isSelected: Bool

    var displayName: String {
        var name = tag
        if !nodeId.isEmpty {
            name += "#\(nodeId)"
        }
        if !classes.isEmpty {
            let cls = classes.split(separator: " ").prefix(2).joined(separator: ".")
            name += ".\(cls)"
        }
        return name
    }
}

extension BrowserDOMNode {
    static func fromJSON(_ json: [String: Any]) -> BrowserDOMNode? {
        guard let tag = json["tag"] as? String else { return nil }
        let nodeId = json["id"] as? String ?? ""
        let classes = json["classes"] as? String ?? ""
        let attrs = json["attributes"] as? [String: String] ?? [:]
        let childrenJSON = json["children"] as? [[String: Any]] ?? []
        let children = childrenJSON.compactMap { BrowserDOMNode.fromJSON($0) }
        return BrowserDOMNode(
            id: UUID(),
            tag: tag,
            nodeId: nodeId,
            classes: classes,
            attributes: attrs,
            children: children,
            isExpanded: true,
            isSelected: false
        )
    }

    func findAndMark(tag: String, nodeId: String) -> BrowserDOMNode? {
        if self.tag == tag && self.nodeId == nodeId {
            var node = self
            node.isSelected = true
            return node
        }
        for i in children.indices {
            if let found = children[i].findAndMark(tag: tag, nodeId: nodeId) {
                var node = self
                node.isExpanded = true
                node.children[i] = found
                return node
            }
        }
        return nil
    }

    func findSelectedId(_ callback: (UUID) -> Void) {
        if isSelected {
            callback(id)
            return
        }
        for child in children {
            child.findSelectedId(callback)
        }
    }
}
