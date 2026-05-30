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
    @State private var dropTargetIndex: Int? = nil
    @State private var dropIsUpperHalf: Bool = false
    @State private var dropIsOverScrollView: Bool = false
    @State private var isInternalDrag: Bool = false
    @State private var isDraggingToEmptyArea: Bool = false
    @State private var renameTagTarget = ""
    @State private var renameTagTask: TaskItem?
    @State private var deletedTask: TaskItem? = nil
    @State private var showUndoToast = false
    @State private var sortOption: SortOption = .manual
    @State private var showTagPicker = false

    private enum SortOption: String, CaseIterable {
        case manual = "Manual"
        case priority = "Priority"
        case created = "Created"
        case dueDate = "Due Date"
    }

    private var visibleTasks: [TaskItem] {
        var result = tasksVM.filteredTasks
        if !showCompleted {
            result = result.filter { !$0.isCompleted }
        }
        switch sortOption {
        case .manual: break
        case .priority:
            let order: [TaskPriority] = [.urgent, .high, .medium, .low]
            result.sort { a, b in
                order.firstIndex(of: a.priority)! < order.firstIndex(of: b.priority)!
            }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        case .dueDate:
            result.sort { a, b in
                switch (a.dueDate, b.dueDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case let (da?, db?): return da < db
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            tagFilterBar
            progressBar
            taskList
            addTaskInput
        }
        .onChange(of: expandedTaskId) { _ in
            editTagInput = ""
        }
        .overlay(alignment: .bottom) {
            if showUndoToast, let task = deletedTask {
                HStack(spacing: 8) {
                    Text("Deleted \"\(task.title)\"")
                        .font(.system(size: 11))
                        .foregroundColor(.textPrimary)
                    Button("Undo") { restoreDeletedTask() }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentBlue)
                        .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.bgSecondary)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: -2)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { restoreDeletedTask() }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showUndoToast)
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
                Menu {
                    ForEach(SortOption.allCases, id: \.rawValue) { opt in
                        Button(action: { sortOption = opt }) {
                            HStack {
                                Text(opt.rawValue)
                                if sortOption == opt {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                        Text(sortOption.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
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
                if tags.count <= 10 {
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
                                            .fill(colorForTag(tag))
                                            .frame(width: 6, height: 6)
                                        Text(tag)
                                            .font(.system(size: 11))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(isSelected ? colorForTag(tag).opacity(0.15) : Color.bgTertiary)
                                    .foregroundColor(isSelected ? colorForTag(tag) : .textSecondary)
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
                            if !tasksVM.selectedTags.isEmpty && !tags.isEmpty {
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
                } else {
                    HStack(spacing: 4) {
                        Button(action: { showTagPicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 10))
                                Text("\(tasksVM.selectedTags.count)/\(tags.count) tags")
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.bgTertiary)
                            .foregroundColor(.textSecondary)
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showTagPicker, arrowEdge: .bottom) {
                            tagPickerContent
                        }

                        if !tasksVM.selectedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(Array(tasksVM.selectedTags).sorted(), id: \.self) { tag in
                                        HStack(spacing: 3) {
                                            Circle().fill(colorForTag(tag)).frame(width: 6, height: 6)
                                            Text(tag).font(.system(size: 11))
                                            Button(action: { tasksVM.selectedTags.remove(tag) }) {
                                                Image(systemName: "xmark").font(.system(size: 8))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .foregroundColor(.textTertiary)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(colorForTag(tag).opacity(0.15))
                                        .foregroundColor(colorForTag(tag))
                                        .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }

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
                    .background(Color.bgSecondary)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
                }
            }
        }
    }

    private var tagPickerContent: some View {
        let tags = tasksVM.allTags
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(tags, id: \.self) { tag in
                    let isSelected = tasksVM.selectedTags.contains(tag)
                    Button(action: {
                        if isSelected {
                            tasksVM.selectedTags.remove(tag)
                        } else {
                            tasksVM.selectedTags.insert(tag)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? colorForTag(tag) : .textTertiary)
                            Circle()
                                .fill(colorForTag(tag))
                                .frame(width: 6, height: 6)
                            Text(tag)
                                .font(.system(size: 11))
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(4)
        }
        .frame(width: 200, height: min(CGFloat(tags.count) * 28 + 8, 300))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let total = tasksVM.tasks.count
        let completed = tasksVM.tasks.filter(\.isCompleted).count
        let fraction = total > 0 ? Double(completed) / Double(total) : 0
        return Group {
            if total > 0 {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.bgTertiary)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentBlue)
                                .frame(width: geo.size.width * fraction, height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(completed)/\(total)")
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.bgSecondary)
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
                        if dropTargetIndex == 0 && dropIsUpperHalf {
                            insertionIndicator()
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                            taskRow(task, index: index, allTasks: items, dropTargetIndex: $dropTargetIndex, dropIsUpperHalf: $dropIsUpperHalf, dropIsOverScrollView: $dropIsOverScrollView)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            if dropTargetIndex == index && !dropIsUpperHalf {
                                insertionIndicator()
                            }
                            Divider()
                                .background(Color.borderDefault)
                        }
                        if isDraggingToEmptyArea {
                            insertionIndicator()
                        }
                    }
                }
                .background(Color.bgPrimary)
                .onDrop(of: [.text], isTargeted: $dropIsOverScrollView) { providers in
                    if dropTargetIndex == nil {
                        isDraggingToEmptyArea = true
                    }
                    return handleTaskDrop(providers: providers, items: items)
                }
            }
        }
    }

    // MARK: - Drag Handle

    private func insertionIndicator() -> some View {
        Rectangle()
            .fill(Color.accentBlue)
            .frame(height: 2)
            .padding(.horizontal, 4)
    }

    private func dragHandle(_ task: TaskItem) -> some View {
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
        .onDrag {
            draggedTaskId = task.id
            isInternalDrag = true
            return NSItemProvider(object: task.id as NSString)
        }
    }

    // MARK: - Task Row

    private func taskRow(_ task: TaskItem, index: Int, allTasks: [TaskItem], dropTargetIndex: Binding<Int?>, dropIsUpperHalf: Binding<Bool>, dropIsOverScrollView: Binding<Bool>) -> some View {
        let isCompleting = completingTaskIds.contains(task.id)
        let isEditing = editingTaskId == task.id
        let isExpanded = expandedTaskId == task.id

        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                dragHandle(task)

                Button(action: { handleToggle(task) }) {
                    Image(systemName: isCompleting ? "checkmark.circle.fill" : task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isCompleting ? .accentGreen : task.isCompleted ? .accentGreen.opacity(0.5) : .textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCompleting)

                if isEditing {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Task title", text: $editTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .onSubmit { finishEditing(task) }
                        TextField("Add description...", text: $editDescription, axis: .vertical)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1...3)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isCompleting || task.isCompleted ? .textTertiary : .textPrimary)
                                .strikethrough(isCompleting || task.isCompleted)
                                .lineLimit(isExpanded ? nil : 1)
                                .onDrag {
                                    let desc = task.description.trimmingCharacters(in: .whitespaces)
                                    let payload = desc.isEmpty ? task.title : "\(task.title) - \(desc)"
                                    return NSItemProvider(object: payload as NSString)
                                }

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
                                        .foregroundColor(colorForTag(tag))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(colorForTag(tag).opacity(0.12))
                                        .cornerRadius(3)
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
                    deleteWithUndo(task)
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
        .onDrop(of: [.text], delegate: TaskDropDelegate(
            task: task,
            index: index,
            allTasks: allTasks,
            draggedTaskId: $draggedTaskId,
            dropTargetIndex: $dropTargetIndex,
            dropIsUpperHalf: $dropIsUpperHalf,
            dropIsOverScrollView: $dropIsOverScrollView,
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
                    tasksVM.updateDescription(updated)
                }
            ), axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .lineLimit(1...5)

            Divider()
                .background(Color.borderLight)

            HStack(spacing: 6) {
                ForEach(task.tags, id: \.self) { tag in
                    HStack(spacing: 2) {
                        Text("#\(tag)")
                            .font(.system(size: 10))
                            .foregroundColor(colorForTag(tag))
                        Button(action: { removeTag(tag, from: task) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 7))
                                .foregroundColor(colorForTag(tag))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(colorForTag(tag).opacity(0.12))
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
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                if let dueDate = task.dueDate {
                    DatePicker("Due", selection: Binding(
                        get: { dueDate },
                        set: { newVal in
                            var updated = task
                            updated.dueDate = newVal
                            tasksVM.updateTask(updated)
                        }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.system(size: 10))
                    .labelsHidden()
                    Button(action: {
                        var updated = task
                        updated.dueDate = nil
                        tasksVM.updateTask(updated)
                    }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Clear due date")
                } else {
                    Button(action: {
                        var updated = task
                        updated.dueDate = Date()
                        tasksVM.updateTask(updated)
                    }) {
                        Text("Add due date")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                Button(action: {
                    deleteWithUndo(task)
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 15))
                .foregroundColor(.accentBlue)
                .padding(.top, 2)
            TextField("Add Task...", text: $newTaskTitle, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .tint(.accentBlue)
                .focused($newTaskFocused)
                .lineLimit(1...5)
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
            tasksVM.toggleTask(id: task.id)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                _ = withAnimation(.easeOut(duration: 0.25)) {
                    completingTaskIds.remove(task.id)
                }
            }
        }
    }

    // MARK: - Helpers

    private let tagColorPalette: [Color] = [
        Color(hex: "#5B8DEC"), Color(hex: "#E06C75"), Color(hex: "#98C379"),
        Color(hex: "#E5C07B"), Color(hex: "#C678DD"), Color(hex: "#56B6C2"),
        Color(hex: "#D19A66"), Color(hex: "#ABB2BF"), Color(hex: "#BE5046"),
        Color(hex: "#61AFEF"),
    ]

    private func colorForTag(_ tag: String) -> Color {
        let index = abs(tag.hashValue) % tagColorPalette.count
        return tagColorPalette[index]
    }

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
        tasksVM.removeTagFromAll(tag)
    }

    private func deleteWithUndo(_ task: TaskItem) {
        deletedTask = task
        showUndoToast = true
        tasksVM.deleteTask(id: task.id)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if deletedTask?.id == task.id {
                withAnimation {
                    showUndoToast = false
                    deletedTask = nil
                }
            }
        }
    }

    private func restoreDeletedTask() {
        guard let task = deletedTask else { return }
        tasksVM.restoreTask(task)
        withAnimation {
            showUndoToast = false
            deletedTask = nil
        }
    }

    private func handleTaskDrop(providers: [NSItemProvider], items: [TaskItem]) -> Bool {
        guard providers.first != nil else { return false }

        if isInternalDrag {
            if let draggedId = draggedTaskId,
               let sourceIdx = items.firstIndex(where: { $0.id == draggedId }) {
                let finalDest: Int
                if isDraggingToEmptyArea {
                    finalDest = items.count
                } else if let destIdx = dropTargetIndex {
                    finalDest = dropIsUpperHalf ? destIdx : destIdx + 1
                } else {
                    finalDest = items.count
                }
                if sourceIdx != finalDest {
                    tasksVM.moveTask(from: sourceIdx, to: finalDest, using: items)
                }
            }
            draggedTaskId = nil
            dropTargetIndex = nil
            isInternalDrag = false
            isDraggingToEmptyArea = false
            return true
        }

        return false
    }
}

// MARK: - Task Drop Delegate

struct TaskDropDelegate: DropDelegate {
    let task: TaskItem
    let index: Int
    let allTasks: [TaskItem]
    @Binding var draggedTaskId: String?
    @Binding var dropTargetIndex: Int?
    @Binding var dropIsUpperHalf: Bool
    @Binding var dropIsOverScrollView: Bool
    let moveAction: (Int, Int) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if dropIsOverScrollView {
            dropTargetIndex = nil
            return DropProposal(operation: .move)
        }
        guard let draggedId = draggedTaskId, draggedId != task.id else {
            dropTargetIndex = nil
            return DropProposal(operation: .move)
        }
        dropTargetIndex = index
        let location = info.location
        let height = 44.0
        dropIsUpperHalf = location.y < height / 2
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if dropIsOverScrollView {
            dropTargetIndex = nil
            return false
        }
        defer {
            draggedTaskId = nil
            dropTargetIndex = nil
        }
        guard let draggedId = draggedTaskId,
              let sourceIndex = allTasks.firstIndex(where: { $0.id == draggedId })
        else { return false }

        var destination: Int
        if let target = dropTargetIndex {
            destination = dropIsUpperHalf ? target : (sourceIndex < target ? target : target + 1)
        } else {
            destination = allTasks.count
        }

        guard sourceIndex != destination else { return false }
        moveAction(sourceIndex, destination)
        return true
    }

    func dragEnded() {
        draggedTaskId = nil
        dropTargetIndex = nil
    }
}
