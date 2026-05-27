import Foundation

struct BrowserResourceEntry: Identifiable, Equatable {
    let id: UUID
    let url: String
    let domain: String
    let mimeType: String
    let statusCode: Int
    let contentLength: Int64

    var fileName: String {
        URL(string: url)?.lastPathComponent ?? url
    }

    var pathExtension: String {
        URL(string: url)?.pathExtension ?? ""
    }

    var language: String {
        switch pathExtension {
        case "js": return "javascript"
        case "ts": return "typescript"
        case "css": return "css"
        case "html", "htm": return "html"
        case "json": return "json"
        case "xml": return "xml"
        case "swift": return "swift"
        case "py": return "python"
        case "rb": return "ruby"
        case "php": return "php"
        case "java": return "java"
        case "rs": return "rust"
        case "go": return "go"
        case "md": return "markdown"
        case "yaml", "yml": return "yaml"
        case "sh", "bash", "zsh": return "bash"
        default: return "plaintext"
        }
    }
}

struct BrowserManifestInfo: Equatable {
    let name: String?
    let shortName: String?
    let description: String?
    let startURL: String?
    let display: String?
    let themeColor: String?
    let backgroundColor: String?
    let icons: [ManifestIcon]
    let json: String

    struct ManifestIcon: Equatable {
        let src: String
        let sizes: String
        let type: String
    }
}

struct BrowserServiceWorkerInfo: Equatable {
    let scriptURL: String
    let state: String
    let isActive: Bool
}

struct BrowserCacheEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let size: Int64
}
