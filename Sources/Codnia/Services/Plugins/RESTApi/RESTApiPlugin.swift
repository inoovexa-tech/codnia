import SwiftUI

public final class RESTApiPlugin: SidebarPlugin {
    public let id = "restapi"
    public let name = "REST API"
    public let iconName = "network"
    public let description = "HTTP/REST API testing client"
    public let author = "Codnia"
    public let version = "1.0.0"

    public var viewModel: RESTApiViewModel?

    public var commands: [PluginCommand] {
        [
            PluginCommand(id: "\(id).newRequest", title: "REST API: New Request") { [weak self] in
                self?.onNewRequest?()
            }
        ]
    }

    var onNewRequest: (() -> Void)?

    public init() {}

    public func makeView() -> AnyView {
        if let vm = viewModel {
            return AnyView(
                RESTApiView()
                    .environmentObject(vm)
            )
        }
        return AnyView(EmptyView())
    }
}