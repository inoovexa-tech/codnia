import SwiftUI

public final class TasksPlugin: SidebarPlugin {
    public let id = "tasks"
    public let name = "Tasks"
    public let iconName = "checklist"
    public let description = "Project task management with tags and priorities"
    public let author = "Codnia"
    public let version = "1.0.0"

    public var commands: [PluginCommand] {
        [
            PluginCommand(id: "\(id).newTask", title: "Tasks: New Task") { [weak self] in
                self?.onNewTask?()
            }
        ]
    }

    var onNewTask: (() -> Void)?

    public init() {}

    public func makeView() -> AnyView {
        AnyView(TasksView())
    }
}
