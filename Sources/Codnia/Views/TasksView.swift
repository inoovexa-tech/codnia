import SwiftUI

struct TasksView: View {
    @EnvironmentObject var tasksVM: TasksViewModel
    @State private var newTaskTitle: String = ""
    @FocusState private var newTaskFocused: Bool
    @State private var editingTaskId: String? = nil
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editTagInput: String = ""
    @State private var expandedTaskId: String? = nil
    @State private var completingTaskIds: Set<String> = []
    @State private var showCompleted: Bool = false
    @State private var showingRenameTag = false
    @State private var renameTagText = ""
    @State private var draggedTaskId: String? = nil
    @State private var renameTagTarget = ""
    @State private var renameTagTask: TaskItem?

    private var visibleTasks: [TaskItem] {
        var result = tasksVM.filteredTasks
        if !showCompleted && tasksVM.searchText.isEmpty {
            result = result.filter { !$0.isCompleted }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            tagFilterBar
            taskList
            addTaskInput
        }
        .alert("Rename Tag", isPresented: $showingRenameTag) {
            TextField("Tag name", text: $renameTagText)
            Button("Rename") {
                let newName = renameTagText.trimmingCharacters(in: .whitespaces).lowercased()
                guard !renameTagTarget.isEmpty, !newName.isEmpty, newName != renameTagTarget else {
                    renameTagTarget = ""
                    renameTagTask = nil
                    return
                }
                if let task = renameTagTask {
                    var updated = task
                    if let idx = updated.tags.firstIndex(of: renameTagTarget) {
                        updated.tags[idx] = newName
                    }
                    tasksVM.updateTask(updated)
                } else {
                    tasksVM.renameTag(renameTagTarget, to: newName)
                }
                renameTagTarget = ""
                renameTagTask = nil
            }
            Button("Cancel", role: .cancel) {
                renameTagTarget = ""
                renameTagTask = nil
            }
        } message: {
            Text("Enter a new name for this tag.")
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textTertiary)
                    .font(.system(size: 12))
                TextField("Search tasks...", text: $tasksVM.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .foregroundColor(.textPrimary)
                if !tasksVM.searchText.isEmpty {
                    Button(action: { tasksVM.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textTertiary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Button(action: { showCompleted.toggle() }) {
                    Text("Completed")
                        .font(.system(size: 10))
                        .foregroundColor(showCompleted ? .accentBlue : .textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(showCompleted ? Color.accentBlue.opacity(0.12) : Color.clear)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.bgSecondary)
        }
    }

    // MARK: - Tag Filter Bar

    private var tagFilterBar: some View {
        let tags = tasksVM.allTags
        return Group {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            let isSelected = tasksVM.selectedTags.contains(tag)
                            Button(action: {
                                if isSelected {
                                    tasksVM.selectedTags.remove(tag)
                                } else {
                                    tasksVM.selectedTags.insert(tag)
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(isSelected ? Color.accentBlue : Color.clear)
                                        .frame(width: 6, height: 6)
                                    Text(tag)
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isSelected ? Color.accentBlue.opacity(0.15) : Color.bgTertiary)
                                .foregroundColor(isSelected ? .accentBlue : .textSecondary)
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(action: {
                                    renameTagTarget = tag
                                    renameTagTask = nil
                                    renameTagText = tag
                                    showingRenameTag = true
                                }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive, action: {
                                    removeTagFromAll(tag)
                                }) {
                                    Label("Remove from all tasks", systemImage: "xmark")
                                }
                            }
                        }
                        if tasksVM.selectedTags.count == tags.count && !tags.isEmpty {
                            Button(action: { tasksVM.selectedTags.removeAll() }) {
                                Text("Clear")
                                    .font(.system(size: 10))
                                    .foregroundColor(.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .background(Color.bgSecondary)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        let items = visibleTasks
        return Group {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundColor(.textTertiary)
                    Text(tasksVM.searchText.isEmpty ? "No tasks" : "No matches")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.bgPrimary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                            taskRow(task, index: index, allTasks: items)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            Divider()
                                .background(Color.borderDefault)
                        }
                    }
                }
                .background(Color.bgPrimary)
            }
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 1) {
                    Circle().frame(width: 3, height: 3)
                    Circle().frame(width: 3, height: 3)
                }
            }
        }
        .foregroundColor(.textTertiary)
        .contentShape(Rectangle())
        .frame(minWidth: 16, minHeight: 20)
        .onHover { hovering in
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Task Row

    private func taskRow(_ task: TaskItem, index: Int, allTasks: [TaskItem]) -> some View {
        let isCompleting = completingTaskIds.contains(task.id)
        let isEditing = editingTaskId == task.id
        let isExpanded = expandedTaskId == task.id

        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                dragHandle

                Button(action: { handleToggle(task) }) {
                    Image(systemName: isCompleting ? "checkmark.circle.fill" : task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isCompleting ? .accentGreen : task.isCompleted ? .accentGreen.opacity(0.5) : .textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCompleting)

                if isEditing {
                    TextField("Task title", text: $editTitle)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .onSubmit { finishEditing(task) }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isCompleting || task.isCompleted ? .textTertiary : .textPrimary)
                                .strikethrough(isCompleting || task.isCompleted)
                                .lineLimit(isExpanded ? nil : 1)

                            priorityBadge(task.priority)

                            if !task.description.isEmpty {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 8))
                                    .foregroundColor(.textTertiary)
                            }
                        }

                        if !task.tags.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(task.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 9))
                                        .foregroundColor(.accentBlue)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.accentBlue.opacity(0.08))
                                        .cornerRadius(3)
                                        .contextMenu {
                                            Button(action: {
                                                renameTagTarget = tag
                                                renameTagTask = task
                                                renameTagText = tag
                                                showingRenameTag = true
                                            }) {
                                                Label("Rename", systemImage: "pencil")
                                            }
                                            Button(role: .destructive, action: {
                                                removeTag(tag, from: task)
                                            }) {
                                                Label("Remove", systemImage: "xmark")
                                            }
                                        }
                                }
                                if task.tags.count > 3 {
                                    Text("+\(task.tags.count - 3)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        }
                    }
                }

                Spacer()

                if !isEditing {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if expandedTaskId == task.id {
                                expandedTaskId = nil
                            } else {
                                expandedTaskId = task.id
                                editingTaskId = nil
                            }
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down.circle" : "ellipsis.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isCompleting ? 0 : 1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .contextMenu {
                Button(action: { startEditing(task) }) {
                    Label("Edit", systemImage: "pencil")
                }
                Button(action: { tasksVM.duplicateTask(id: task.id) }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Divider()
                Section {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Button(action: {
                            var updated = task
                            updated.priority = p
                            tasksVM.updateTask(updated)
                        }) {
                            HStack {
                                Text(p.rawValue.capitalized)
                                Spacer()
                                if task.priority == p {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Priority")
                }
                Divider()
                Button(role: .destructive, action: {
                    withAnimation { tasksVM.deleteTask(id: task.id) }
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }

            if isExpanded && !isEditing {
                expandedTaskSection(task)
            }
        }
        .background(Color.bgPrimary)
        .opacity(isCompleting ? 0.4 : 1)
        .onDrag {
            draggedTaskId = task.id
            return NSItemProvider(object: task.id as NSString)
        }
        .onDrop(of: [.text], delegate: TaskDropDelegate(
            task: task,
            index: index,
            allTasks: allTasks,
            draggedTaskId: $draggedTaskId,
            moveAction: { source, dest in
                tasksVM.moveTask(from: source, to: dest, using: allTasks)
            }
        ))
    }

    // MARK: - Expanded Task Section

    private func expandedTaskSection(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Add description...", text: Binding(
                get: { task.description },
                set: { newVal in
                    var updated = task
                    updated.description = newVal
                    tasksVM.updateTask(updated)
                }
            ))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

            Divider()
                .background(Color.borderLight)

            HStack(spacing: 6) {
                ForEach(task.tags, id: \.self) { tag in
                    HStack(spacing: 2) {
                        Text("#\(tag)")
                            .font(.system(size: 10))
                            .foregroundColor(.accentBlue)
                        Button(action: { removeTag(tag, from: task) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 7))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentBlue.opacity(0.1))
                    .cornerRadius(3)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                TextField("Add tag...", text: $editTagInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .onSubmit { addTag(to: task) }
                Button(action: { addTag(to: task) }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.accentBlue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(editTagInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Text(task.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }

            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    Button(action: {
                        var updated = task
                        updated.priority = p
                        tasksVM.updateTask(updated)
                    }) {
                        Text(p.rawValue.capitalized)
                            .font(.system(size: 10))
                            .foregroundColor(task.priority == p ? priorityColor(p) : .textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.priority == p ? priorityColor(p).opacity(0.12) : Color.clear)
                            .cornerRadius(3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                Button(action: {
                    withAnimation { tasksVM.deleteTask(id: task.id) }
                    expandedTaskId = nil
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.accentRed)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
    }

    // MARK: - Add Task Input

    private var addTaskInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 15))
                .foregroundColor(.accentBlue)
            TextField("Add Task...", text: $newTaskTitle)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .tint(.accentBlue)
                .focused($newTaskFocused)
                .onSubmit(commitNewTask)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
        .onTapGesture { newTaskFocused = true }
    }

    private func commitNewTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            tasksVM.addTask(title: trimmed)
        }
        newTaskTitle = ""
        newTaskFocused = true
    }

    // MARK: - Toggle with animation

    private func handleToggle(_ task: TaskItem) {
        guard !completingTaskIds.contains(task.id) else { return }

        if task.isCompleted {
            tasksVM.toggleTask(id: task.id)
        } else {
            completingTaskIds.insert(task.id)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeOut(duration: 0.25)) {
                    tasksVM.toggleTask(id: task.id)
                    completingTaskIds.remove(task.id)
                }
            }
        }
    }

    // MARK: - Helpers

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        Image(systemName: priorityIcon(priority))
            .font(.system(size: 9))
            .foregroundColor(priorityColor(priority))
    }

    private func priorityIcon(_ priority: TaskPriority) -> String {
        switch priority {
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark"
        case .urgent: return "exclamationmark.2"
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .textTertiary
        case .medium: return .accentBlue
        case .high: return .accentOrange
        case .urgent: return .accentRed
        }
    }

    private func startEditing(_ task: TaskItem) {
        editingTaskId = task.id
        editTitle = task.title
        editDescription = task.description
        expandedTaskId = nil
    }

    private func finishEditing(_ original: TaskItem) {
        guard editingTaskId != nil else { return }
        let trimmed = editTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            var updated = original
            updated.title = trimmed
            updated.description = editDescription
            tasksVM.updateTask(updated)
        }
        editingTaskId = nil
        editTitle = ""
        editDescription = ""
    }

    private func saveDescription(_ task: TaskItem) {
        var updated = task
        updated.description = editDescription
        tasksVM.updateTask(updated)
    }

    private func addTag(to task: TaskItem) {
        let tag = editTagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !task.tags.contains(tag) else { return }
        var updated = task
        updated.tags.append(tag)
        tasksVM.updateTask(updated)
        editTagInput = ""
    }

    private func removeTag(_ tag: String, from task: TaskItem) {
        var updated = task
        updated.tags.removeAll { $0 == tag }
        tasksVM.updateTask(updated)
    }

    private func removeTagFromAll(_ tag: String) {
        for i in tasksVM.tasks.indices {
            tasksVM.tasks[i].tags.removeAll { $0 == tag }
        }
        tasksVM.saveToDisk()
        tasksVM.selectedTags.remove(tag)
    }
}

// MARK: - Task Drop Delegate

struct TaskDropDelegate: DropDelegate {
    let task: TaskItem
    let index: Int
    let allTasks: [TaskItem]
    @Binding var draggedTaskId: String?
    let moveAction: (Int, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedTaskId = nil }
        guard let draggedId = draggedTaskId,
              let sourceIndex = allTasks.firstIndex(where: { $0.id == draggedId }),
              sourceIndex != index
        else { return false }
        moveAction(sourceIndex, index)
        return true
    }
}
