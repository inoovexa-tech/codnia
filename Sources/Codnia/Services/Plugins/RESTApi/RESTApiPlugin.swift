import SwiftUI

public final class RESTApiPlugin: SidebarPlugin {
    public let id = "restapi"
    public let name = "REST API"
    public let iconName = "network"
    public let description = "HTTP/REST API testing client"
    public let author = "Codnia"
    public let version = "1.0.0"

    private let viewModel: RESTApiViewModel

    public var commands: [PluginCommand] {
        [
            PluginCommand(id: "\(id).newRequest", title: "REST API: New Request") { [weak self] in
                self?.onNewRequest?()
            }
        ]
    }

    var onNewRequest: (() -> Void)?

    public init() {
        self.viewModel = RESTApiViewModel()
    }

    public func makeView() -> AnyView {
        AnyView(
            RESTApiView()
                .environmentObject(viewModel)
        )
    }
}