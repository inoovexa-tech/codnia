import SwiftUI
import UniformTypeIdentifiers

struct NotesView: View {
    @EnvironmentObject var notesVM: NotesViewModel
    @EnvironmentObject var workspaceVM: WorkspaceService
    @EnvironmentObject var editorVM: EditorViewModel
    @EnvironmentObject var pluginService: PluginService

    @State private var newNoteName: String = ""
    @State private var newNoteDirectory: String = ""
    @State private var selectedTemplateId: String?
    @State private var showNewFolderSheet: Bool = false
    @State private var newFolderName: String = ""
    @State private var showCreateError: Bool = false
    @State private var createErrorMessage: String = ""
    @State private var showTagPicker = false

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            tagFilterBar
            notesListContent
            actionBar
        }
        .onAppear {
            loadNotes()
        }
        .onChange(of: workspaceVM.currentWorkspacePath) { _ in
            loadNotes()
        }
        .sheet(isPresented: $notesVM.showNewNoteSheet) {
            newNoteSheet
        }
        .sheet(isPresented: $showNewFolderSheet) {
            newFolderSheet
        }
        .alert("Delete Note", isPresented: $notesVM.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let entry = notesVM.noteToDelete {
                    try? notesVM.deleteNote(entry)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(notesVM.noteToDelete?.name ?? "")\"?")
        }
        .alert("Error", isPresented: $showCreateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(createErrorMessage)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textTertiary)
                .font(.system(size: 12))
            TextField("Search notes...", text: $notesVM.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
            if !notesVM.searchText.isEmpty {
                Button(action: { notesVM.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textTertiary)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.bgSecondary)
    }

    private var tagFilterBar: some View {
        let tags = notesVM.allTags
        return Group {
            if !tags.isEmpty {
                if tags.count <= 10 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                let isSelected = notesVM.selectedTags.contains(tag)
                                Button(action: {
                                    if isSelected {
                                        notesVM.selectedTags.remove(tag)
                                    } else {
                                        notesVM.selectedTags.insert(tag)
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
                            }
                            if !notesVM.selectedTags.isEmpty {
                                Button(action: { notesVM.selectedTags.removeAll() }) {
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
                                Text("\(notesVM.selectedTags.count)/\(tags.count) tags")
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
                            tagPickerContent(tags: tags)
                        }

                        if !notesVM.selectedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(Array(notesVM.selectedTags).sorted(), id: \.self) { tag in
                                        HStack(spacing: 3) {
                                            Circle()
                                                .fill(Color.accentBlue)
                                                .frame(width: 6, height: 6)
                                            Text(tag).font(.system(size: 11))
                                            Button(action: { notesVM.selectedTags.remove(tag) }) {
                                                Image(systemName: "xmark").font(.system(size: 8))
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .foregroundColor(.textTertiary)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.accentBlue.opacity(0.15))
                                        .foregroundColor(.accentBlue)
                                        .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }

                            Button(action: { notesVM.selectedTags.removeAll() }) {
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

    private func tagPickerContent(tags: [String]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(tags, id: \.self) { tag in
                    let isSelected = notesVM.selectedTags.contains(tag)
                    Button(action: {
                        if isSelected {
                            notesVM.selectedTags.remove(tag)
                        } else {
                            notesVM.selectedTags.insert(tag)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? .accentBlue : .textTertiary)
                            Circle()
                                .fill(isSelected ? Color.accentBlue : Color.clear)
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

    private var notesListContent: some View {
        Group {
            if notesVM.isLoading {
                loadingView
            } else if notesVM.filteredEntries.isEmpty {
                emptyStateView
            } else {
                notesList
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading notes...")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgPrimary)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.textTertiary)
            Text("No notes yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
            Text("Create your first note to get started")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
            Button(action: { notesVM.showNewNoteSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New Note")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentBlue)
                .cornerRadius(6)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.bgPrimary)
    }

    private var notesList: some View {
        let items = notesVM.filteredEntries
        return ScrollView {
            LazyVStack(spacing: 0) {
                if !notesVM.favoriteEntries.isEmpty && notesVM.searchText.isEmpty {
                    sectionHeader("Favorites", icon: "star.fill", color: .accentYellow)
                    ForEach(notesVM.favoriteEntries) { entry in
                        noteRow(entry)
                        Divider().background(Color.borderDefault)
                    }
                }

                if !notesVM.recentEntries.isEmpty && notesVM.searchText.isEmpty {
                    sectionHeader("Recent", icon: "clock", color: .textTertiary)
                    ForEach(notesVM.recentEntries) { entry in
                        noteRow(entry)
                        Divider().background(Color.borderDefault)
                    }
                }

                if notesVM.searchText.isEmpty {
                    directoryList
                } else {
                    sectionHeader("All Notes", icon: "folder", color: .textTertiary)
                    ForEach(items) { entry in
                        noteRow(entry)
                        Divider().background(Color.borderDefault)
                    }
                }
            }
        }
        .background(Color.bgPrimary)
    }

    @ViewBuilder
    private var directoryList: some View {
        let root = notesVM.filteredRootStructure
        let hasSubdirs = !root.directories.isEmpty

        if hasSubdirs {
            rootHeader("Notes")
            ForEach(root.directories) { dir in
                DirectoryRowView(dir: dir, indent: 0, notesVM: notesVM, editorVM: editorVM, onOpen: openNote)
                Divider().background(Color.borderDefault)
            }
            if !root.notes.isEmpty {
                ForEach(root.notes) { entry in
                    noteRow(entry)
                    Divider().background(Color.borderDefault)
                }
            }
        } else {
            rootHeader("All Notes")
            ForEach(root.notes) { entry in
                noteRow(entry)
                Divider().background(Color.borderDefault)
            }
        }
    }

    private func rootHeader(_ title: String) -> some View {
        let isTargeted = Binding<Bool>(
            get: { notesVM.dropTargetPath == notesVM.rootNotesPath },
            set: { if $0 { notesVM.dropTargetPath = notesVM.rootNotesPath } else { notesVM.dropTargetPath = nil } }
        )
        return sectionHeader(title, icon: "folder", color: .textTertiary)
            .background(notesVM.dropTargetPath == notesVM.rootNotesPath ? Color.accentBlue.opacity(0.1) : Color.clear)
            .onDrop(of: [.text], isTargeted: isTargeted) { providers in
                handleNoteDrop(providers: providers, targetDir: notesVM.rootNotesPath)
            }
    }

    private func handleNoteDrop(providers: [NSItemProvider], targetDir: String) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [notesVM] item, _ in
            let sourcePath: String
            if let str = item as? String {
                sourcePath = str
            } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                sourcePath = str
            } else {
                return
            }
            guard sourcePath != targetDir else { return }
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let fileName = sourceURL.lastPathComponent
            let destination = URL(fileURLWithPath: targetDir).appendingPathComponent(fileName)
            guard sourceURL.path != destination.path else { return }
            if FileManager.default.fileExists(atPath: destination.path) { return }
            try? FileManager.default.moveItem(at: sourceURL, to: destination)
            DispatchQueue.main.async {
                notesVM.refreshNotes()
            }
        }
        return true
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
    }

    private func noteRow(_ entry: NoteEntry, indent: Int = 0) -> some View {
        NoteRowView(
            entry: entry,
            indent: indent,
            notesVM: notesVM,
            editorVM: editorVM,
            onOpen: openNote
        )
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            Menu {
                Button(action: { notesVM.showNewNoteSheet = true }) {
                    Label("New Note", systemImage: "doc.text")
                }
                Button(action: { showNewFolderSheet = true }) {
                    Label("New Folder", systemImage: "folder")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New")
                }
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)

            Rectangle()
                .fill(Color.borderDefault)
                .frame(width: 1, height: 20)

            Menu {
                ForEach(NoteSortOrder.allCases, id: \.rawValue) { order in
                    Button(action: { notesVM.sortOrder = order }) {
                        HStack {
                            Text(order.rawValue)
                            if notesVM.sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(notesVM.sortOrder.rawValue)
                }
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)

            Rectangle()
                .fill(Color.borderDefault)
                .frame(width: 1, height: 20)

            Button(action: { notesVM.refreshNotes() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
    }

    private var newNoteSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentBlue.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentBlue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Note")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("Create a new markdown note")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
                
                Button(action: {
                    notesVM.showNewNoteSheet = false
                    newNoteName = ""
                    selectedTemplateId = nil
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(Color.bgTertiary)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.bgSecondary)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .bottom)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Note Name
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "textformat")
                                .font(.system(size: 9))
                                .foregroundColor(.textTertiary)
                            Text("NOTE NAME")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.textTertiary)
                                .tracking(0.5)
                        }
                        TextField("Enter note title...", text: $newNoteName)
                            .font(.system(size: 13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.bgSecondary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(newNoteName.isEmpty ? Color.borderDefault : Color.accentBlue.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                                .foregroundColor(.textTertiary)
                            Text("LOCATION")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.textTertiary)
                                .tracking(0.5)
                        }
                        HStack(spacing: 0) {
                            Text(".codnia/notes/")
                                .font(.system(size: 12))
                                .foregroundColor(.textTertiary)
                                .padding(.leading, 12)
                            TextField("subfolder (optional)", text: $newNoteDirectory)
                                .font(.system(size: 12))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 10)
                        }
                        .background(Color.bgSecondary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                    }
                    
                    // Templates
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.textTertiary)
                            Text("TEMPLATE")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.textTertiary)
                                .tracking(0.5)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            // Blank option
                            templateCard(
                                id: nil,
                                name: "Blank",
                                icon: "doc",
                                description: "Empty note"
                            )
                            
                            ForEach(notesVM.templates) { template in
                                templateCard(
                                    id: template.id,
                                    name: template.name,
                                    icon: template.icon,
                                    description: templatePreview(template)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            
            Spacer()
            
            // Footer buttons
            HStack(spacing: 10) {
                Button(action: {
                    notesVM.showNewNoteSheet = false
                    newNoteName = ""
                    selectedTemplateId = nil
                }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.bgTertiary)
                        .cornerRadius(7)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: createNewNote) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Create Note")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(newNoteName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentBlue.opacity(0.5) : Color.accentBlue)
                    .cornerRadius(7)
                }
                .disabled(newNoteName.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.bgSecondary)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDefault), alignment: .top)
        }
        .frame(width: 380, height: 520)
        .background(Color.bgPrimary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
    }
    
    private func templateCard(id: String?, name: String, icon: String, description: String) -> some View {
        let isSelected = selectedTemplateId == id
        
        return Button(action: { selectedTemplateId = id }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentBlue.opacity(0.15) : Color.bgTertiary)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .accentBlue : .textTertiary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .textPrimary : .textSecondary)
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentBlue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentBlue.opacity(0.08) : Color.bgSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentBlue.opacity(0.3) : Color.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func templatePreview(_ template: NoteTemplate) -> String {
        switch template.name {
        case "Meeting Notes": return "Attendees, agenda, action items"
        case "Task List": return "To do, in progress, done"
        case "Daily Journal": return "Morning, afternoon, gratitude"
        case "Project Notes": return "Overview, goals, progress"
        default: return "Template"
        }
    }

    private var newFolderSheet: some View {
        VStack(spacing: 16) {
            Text("New Folder")
                .font(.system(size: 14, weight: .semibold))
            TextField("Folder name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") {
                    showNewFolderSheet = false
                }
                Button("Create") {
                    try? notesVM.createFolder(name: newFolderName, inDirectory: newNoteDirectory)
                    showNewFolderSheet = false
                }
                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func loadNotes() {
        notesVM.loadNotes(from: workspaceVM.currentWorkspacePath)
    }

    private func openNote(_ entry: NoteEntry) {
        editorVM.openFile(notesVM.openNote(entry))
    }

    private func createNewNote() {
        let name = newNoteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        do {
            let path: String
            if let templateId = selectedTemplateId {
                path = try notesVM.createNoteFromTemplate(name: name, inDirectory: newNoteDirectory, templateId: templateId)
            } else {
                path = try notesVM.createNote(name: name, inDirectory: newNoteDirectory, content: "")
            }
            editorVM.openFile(path)
            notesVM.showNewNoteSheet = false
            newNoteName = ""
        } catch {
            createErrorMessage = (error as? NotesError)?.errorDescription ?? error.localizedDescription
            showCreateError = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        Self.formatNoteDate(date)
    }

    fileprivate static func formatNoteDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

private struct NoteRowView: View {
    let entry: NoteEntry
    let indent: Int
    @ObservedObject var notesVM: NotesViewModel
    @ObservedObject var editorVM: EditorViewModel
    let onOpen: (NoteEntry) -> Void

    var body: some View {
        let fileName = entry.name.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: ".markdown", with: "")
        let displayName = entry.frontmatterTitle?.isEmpty == false ? entry.frontmatterTitle! : fileName
        let isEditing = notesVM.editingNoteId == entry.id

        return HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .frame(width: 20)

            if isEditing {
                TextField("", text: $notesVM.editingNoteText, onCommit: {
                    if let entry = notesVM.entries.first(where: { $0.id == notesVM.editingNoteId }) {
                        try? notesVM.renameNote(entry, to: notesVM.editingNoteText)
                    }
                    notesVM.cancelEditing()
                })
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
                .onExitCommand { notesVM.cancelEditing() }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.system(size: 12))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    if let preview = entry.preview, notesVM.searchText.isEmpty {
                        Text(preview)
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    } else if displayName != fileName {
                        Text(fileName)
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button(action: { notesVM.toggleFavorite(entry) }) {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundColor(entry.isFavorite ? .accentYellow : .textTertiary)
            }
            .buttonStyle(PlainButtonStyle())

            if let date = entry.modifiedAt {
                Text(NotesView.formatNoteDate(date))
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.leading, CGFloat(indent * 16))
        .padding(.vertical, isEditing ? 6 : 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                notesVM.cancelEditing()
            } else {
                onOpen(entry)
            }
        }
        .onDrag {
            let provider = NSItemProvider(object: entry.path as NSString)
            if let content = try? String(contentsOfFile: entry.path, encoding: .utf8) {
                provider.registerObject(content as NSString, visibility: .all)
            }
            return provider
        }
        .contextMenu {
            Button(action: { onOpen(entry) }) {
                Label("Open", systemImage: "doc.text")
            }
            Button(action: {
                notesVM.startEditing(entry)
            }) {
                Label("Rename", systemImage: "pencil")
            }
            Button(action: {
                if let path = try? notesVM.duplicateNote(entry) {
                    editorVM.openFile(path)
                }
            }) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Divider()
            Button(action: { notesVM.toggleFavorite(entry) }) {
                Label(entry.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: entry.isFavorite ? "star.slash" : "star")
            }
            Divider()
            Button(action: {
                notesVM.noteToDelete = entry
                notesVM.showDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct DirectoryRowView: View {
    let dir: NoteDirectory
    let indent: Int
    @ObservedObject var notesVM: NotesViewModel
    @ObservedObject var editorVM: EditorViewModel
    let onOpen: (NoteEntry) -> Void

    @State private var isDropTarget = false

    var body: some View {
        let isExpanded = notesVM.expandedDirectories.contains(dir.path)
        return VStack(spacing: 0) {
            Button(action: {
                notesVM.toggleDirectoryExpanded(dir.path)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                        .frame(width: 12)

                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                        .frame(width: 16)

                    Text(dir.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.leading, CGFloat(8 + indent * 16))
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(isDropTarget ? Color.accentBlue.opacity(0.12) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onDrop(of: [.text], isTargeted: $isDropTarget) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [notesVM] item, _ in
                    let sourcePath: String
                    if let str = item as? String {
                        sourcePath = str
                    } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                        sourcePath = str
                    } else {
                        return
                    }
                    let sourceURL = URL(fileURLWithPath: sourcePath)
                    let fileName = sourceURL.lastPathComponent
                    let destination = URL(fileURLWithPath: dir.path).appendingPathComponent(fileName)
                    guard sourceURL.path != destination.path else { return }
                    if FileManager.default.fileExists(atPath: destination.path) { return }
                    try? FileManager.default.moveItem(at: sourceURL, to: destination)
                    DispatchQueue.main.async {
                        notesVM.refreshNotes()
                    }
                }
                return true
            }

            if isExpanded {
                if !dir.directories.isEmpty {
                    ForEach(dir.directories) { subDir in
                        DirectoryRowView(dir: subDir, indent: indent + 1, notesVM: notesVM, editorVM: editorVM, onOpen: onOpen)
                        Divider().background(Color.borderDefault)
                    }
                }
                if !dir.notes.isEmpty {
                    ForEach(dir.notes) { entry in
                        NoteRowView(entry: entry, indent: indent + 1, notesVM: notesVM, editorVM: editorVM, onOpen: onOpen)
                        Divider().background(Color.borderDefault)
                    }
                }
            }
        }
    }
}