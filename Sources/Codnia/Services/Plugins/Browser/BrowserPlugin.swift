import Foundation
import SwiftUI

@MainActor
public final class BrowserPlugin: SidebarPlugin {
    public let id = "browser"
    public let name = "Browser"
    public let iconName = "globe"
    public let description = "History, downloads, and saved credentials for the integrated browser"
    public let author = "Codnia"
    public let version = "1.0.0"

    public var commands: [PluginCommand] {
        [
            PluginCommand(id: "\(id).newTab", title: "Browser: New Tab") { [weak self] in
                self?.onNewTab?()
            },
            PluginCommand(id: "\(id).clearHistory", title: "Browser: Clear History") { [weak self] in
                self?.onClearHistory?()
            },
            PluginCommand(id: "\(id).showDownloads", title: "Browser: Show Downloads") { [weak self] in
                self?.onShowDownloads?()
            }
        ]
    }

    public var onNewTab: (() -> Void)?
    public var onClearHistory: (() -> Void)?
    public var onShowDownloads: (() -> Void)?

    public init() {}

    public func makeView() -> AnyView {
        AnyView(BrowserSidebarView())
    }
}
