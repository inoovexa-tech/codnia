import Foundation

struct BrowserCSSStyle: Identifiable, Equatable {
    let id: UUID
    let selector: String
    let properties: [String: String]
    let source: String
    let isInherited: Bool
    let isOverridden: Bool

    init(
        selector: String,
        properties: [String: String],
        source: String,
        isInherited: Bool = false,
        isOverridden: Bool = false
    ) {
        self.id = UUID()
        self.selector = selector
        self.properties = properties
        self.source = source
        self.isInherited = isInherited
        self.isOverridden = isOverridden
    }
}

struct BrowserComputedStyle: Equatable {
    let properties: [String: String]
    let boxModel: BrowserBoxModel?

    init(properties: [String: String], boxModel: BrowserBoxModel? = nil) {
        self.properties = properties
        self.boxModel = boxModel
    }
}

struct BrowserBoxModel: Equatable {
    let margin: EdgeInsets
    let border: EdgeInsets
    let padding: EdgeInsets
    let content: CGSize

    struct EdgeInsets: Equatable {
        let top: String
        let right: String
        let bottom: String
        let left: String
    }

    init(margin: EdgeInsets, border: EdgeInsets, padding: EdgeInsets, content: CGSize) {
        self.margin = margin
        self.border = border
        self.padding = padding
        self.content = content
    }

    static func fromJSON(_ json: [String: Any]) -> BrowserBoxModel? {
        guard
            let marginDict = json["margin"] as? [String: String],
            let borderDict = json["border"] as? [String: String],
            let paddingDict = json["padding"] as? [String: String],
            let contentDict = json["content"] as? [String: Double]
        else { return nil }

        return BrowserBoxModel(
            margin: EdgeInsets(top: marginDict["top"] ?? "0", right: marginDict["right"] ?? "0", bottom: marginDict["bottom"] ?? "0", left: marginDict["left"] ?? "0"),
            border: EdgeInsets(top: borderDict["top"] ?? "0", right: borderDict["right"] ?? "0", bottom: borderDict["bottom"] ?? "0", left: borderDict["left"] ?? "0"),
            padding: EdgeInsets(top: paddingDict["top"] ?? "0", right: paddingDict["right"] ?? "0", bottom: paddingDict["bottom"] ?? "0", left: paddingDict["left"] ?? "0"),
            content: CGSize(width: contentDict["width"] ?? 0, height: contentDict["height"] ?? 0)
        )
    }
}
