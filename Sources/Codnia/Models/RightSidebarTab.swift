import Foundation

public enum RightSidebarTab: Hashable {
    case explorer
    case search
    case sourceControl
    case plugin(String)

    public var id: String {
        switch self {
        case .explorer: return "explorer"
        case .search: return "search"
        case .sourceControl: return "sourceControl"
        case .plugin(let id): return id
        }
    }
}
