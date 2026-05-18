import Foundation

public enum SplitDirection: String, Codable, Equatable {
    case horizontal
    case vertical
}

public struct SplitLeaf: Codable, Equatable {
    public var id: UUID
    public var tabId: String?
    public var terminalId: String?
    public var sessionId: String?

    public init(id: UUID = UUID(), tabId: String? = nil, terminalId: String? = nil, sessionId: String? = nil) {
        self.id = id
        self.tabId = tabId
        self.terminalId = terminalId
        self.sessionId = sessionId
    }

    public var viewId: UUID { id }
}

public struct SplitContainer: Codable, Equatable {
    public var id: UUID
    public var direction: SplitDirection
    public var first: SplitPane
    public var second: SplitPane
    public var proportion: CGFloat

    public init(id: UUID = UUID(), direction: SplitDirection, first: SplitPane, second: SplitPane, proportion: CGFloat = 0.5) {
        self.id = id
        self.direction = direction
        self.first = first
        self.second = second
        self.proportion = proportion
    }
}

public indirect enum SplitPane: Codable, Equatable {
    case leaf(SplitLeaf)
    case split(SplitContainer)

    public var allLeafIds: [UUID] {
        switch self {
        case .leaf(let leaf): return [leaf.id]
        case .split(let c): return c.first.allLeafIds + c.second.allLeafIds
        }
    }

    public var leafCount: Int {
        switch self {
        case .leaf: return 1
        case .split(let c): return c.first.leafCount + c.second.leafCount
        }
    }

    public func findLeaf(id: UUID) -> SplitLeaf? {
        switch self {
        case .leaf(let leaf):
            return leaf.id == id ? leaf : nil
        case .split(let c):
            return c.first.findLeaf(id: id) ?? c.second.findLeaf(id: id)
        }
    }

    public func replacingLeaf(id: UUID, with newPane: SplitPane) -> SplitPane {
        switch self {
        case .leaf(let leaf):
            if leaf.id == id { return newPane }
            return self
        case .split(let c):
            let f = c.first.replacingLeaf(id: id, with: newPane)
            let s = c.second.replacingLeaf(id: id, with: newPane)
            return .split(SplitContainer(id: c.id, direction: c.direction, first: f, second: s))
        }
    }

    public func removingLeaf(id: UUID) -> SplitPane? {
        switch self {
        case .leaf(let leaf):
            return leaf.id == id ? nil : self
        case .split(let c):
            guard let f = c.first.removingLeaf(id: id) else {
                return c.second.removingLeaf(id: id)
            }
            guard let s = c.second.removingLeaf(id: id) else {
                return f
            }
            return .split(SplitContainer(id: c.id, direction: c.direction, first: f, second: s))
        }
    }

    @discardableResult
    public mutating func mutateLeaf(id: UUID, mutation: (inout SplitLeaf) -> Void) -> Bool {
        switch self {
        case .leaf(var leaf):
            if leaf.id == id {
                mutation(&leaf)
                self = .leaf(leaf)
                return true
            }
            return false
        case .split(var c):
            if c.first.mutateLeaf(id: id, mutation: mutation) {
                self = .split(c)
                return true
            }
            if c.second.mutateLeaf(id: id, mutation: mutation) {
                self = .split(c)
                return true
            }
            return false
        }
    }

    public func mapLeafTabIds(to tabId: String) -> SplitPane {
        switch self {
        case .leaf(var leaf):
            leaf.tabId = tabId
            return .leaf(leaf)
        case .split(let c):
            return .split(SplitContainer(
                id: c.id,
                direction: c.direction,
                first: c.first.mapLeafTabIds(to: tabId),
                second: c.second.mapLeafTabIds(to: tabId),
                proportion: c.proportion
            ))
        }
    }

    @discardableResult
    public mutating func mutateContainer(id: UUID, mutation: (inout SplitContainer) -> Void) -> Bool {
        switch self {
        case .leaf:
            return false
        case .split(var c):
            if c.id == id {
                mutation(&c)
                self = .split(c)
                return true
            }
            if c.first.mutateContainer(id: id, mutation: mutation) {
                self = .split(c)
                return true
            }
            if c.second.mutateContainer(id: id, mutation: mutation) {
                self = .split(c)
                return true
            }
            return false
        }
    }
}
