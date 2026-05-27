import SwiftUI

struct RESTApiView: View {
    @EnvironmentObject var viewModel: RESTApiViewModel
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var renamingCollectionId: String?

    private var selectedCollection: EndpointCollection? {
        guard let id = viewModel.selectedCollectionId else { return nil }
        return viewModel.collections.first { $0.id == id }
    }
    @State private var renamingCollectionName: String = ""
    @State private var showRenameCollectionSheet: Bool = false
    @State private var showingAllHistory: Bool = false
    @State private var isDraggingOver: Bool = false

    @State private var endpointToMove: HTTPEndpoint?
    @State private var showMoveToCollection: Bool = false

    @State private var endpointToRename: HTTPEndpoint?
    @State private var showRenameEndpoint: Bool = false
    @State private var renameEndpointName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    if let collection = selectedCollection {
                        collectionDetail(collection)
                    } else {
                        collectionsSection
                    }
                    Divider().background(Color.borderDefault)
                    historySection
                }
            }
        }
        .sheet(isPresented: $viewModel.showEnvironmentEditor) {
            EnvironmentEditorView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showNewCollectionSheet) {
            newCollectionSheet
        }
        .sheet(isPresented: $showRenameCollectionSheet) {
            renameCollectionSheet
        }
        .sheet(isPresented: $showingAllHistory) {
            allHistorySheet
        }
        .sheet(isPresented: $showRenameEndpoint) {
            renameEndpointSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            if viewModel.selectedCollectionId != nil {
                Button(action: { viewModel.selectedCollectionId = nil }) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                        Text("Collections")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.accentBlue)
                }
                .buttonStyle(PlainButtonStyle())

                Text(selectedCollection?.name ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button(action: openNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
            } else {
                Button(action: { viewModel.showEnvironmentEditor = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                        Text(viewModel.activeEnvironment?.name ?? "No Environment")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: openNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    // MARK: - Collections Section

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COLLECTIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)

                Spacer()

                Button(action: { viewModel.showNewCollectionSheet = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if viewModel.collections.isEmpty {
                emptyCollectionsView
            } else {
                ForEach(viewModel.collections) { collection in
                    collectionRow(collection)
                }
            }
        }
    }

    private var emptyCollectionsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 28))
                .foregroundColor(.textTertiary)

            Text("No collections")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)

            Text("Save requests to organize them")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)

            Button("New Collection") {
                viewModel.showNewCollectionSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func collectionRow(_ collection: EndpointCollection) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)

            Text(collection.name)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)

            Spacer()

            Text("\(collection.endpoints.count)")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedCollectionId = collection.id
        }
        .contextMenu {
            Button("Rename") {
                renamingCollectionId = collection.id
                renamingCollectionName = collection.name
                showRenameCollectionSheet = true
            }
            Button("Delete", role: .destructive) {
                viewModel.endpointStore.removeCollection(collection)
            }
        }
        .onDrop(of: [.text], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers, to: collection)
        }
    }

    // MARK: - Collection Detail (Requests list)

    private func collectionDetail(_ collection: EndpointCollection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("REQUESTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if collection.endpoints.isEmpty {
                VStack(spacing: 4) {
                    Text("No requests")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(collection.endpoints) { endpoint in
                    endpointRow(endpoint)
                }
            }
        }
    }

    private func endpointRow(_ endpoint: HTTPEndpoint) -> some View {
        HStack(spacing: 6) {
            Text(endpoint.request.method.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(methodColor(endpoint.request.method))
                .frame(width: 34)

            Text(endpoint.name.isEmpty ? endpoint.request.url : endpoint.name)
                .font(.system(size: 11))
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            openEndpoint(endpoint)
        }
        .contextMenu {
            Button("Rename") {
                endpointToRename = endpoint
                renameEndpointName = endpoint.name
                showRenameEndpoint = true
            }
            Button("Delete", role: .destructive) {
                viewModel.endpointStore.removeEndpoint(endpoint)
            }
            if viewModel.collections.count > 1 {
                Divider()
                ForEach(viewModel.collections) { collection in
                    if collection.id != viewModel.selectedCollectionId {
                        Button("Move to \"\(collection.name)\"") {
                            viewModel.endpointStore.moveEndpoint(endpoint, to: collection.id)
                        }
                    }
                }
            }
        }
        .draggable(endpoint.id)
    }

    private func methodBadge(_ method: HTTPMethod) -> some View {
        Text(method.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(methodColor(method))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(methodColor(method).opacity(0.15))
            .cornerRadius(3)
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .get: return .accentBlue
        case .post: return .accentGreen
        case .put: return .accentYellow
        case .patch: return .accentOrange
        case .delete: return .accentRed
        case .head, .options: return .textTertiary
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HISTORY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textTertiary)

                Spacer()

                if !viewModel.history.isEmpty {
                    Button(action: { viewModel.endpointStore.history.removeAll(); viewModel.endpointStore.saveHistory() }) {
                        Text("Clear")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if viewModel.history.isEmpty {
                Text("No history")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(viewModel.history.prefix(20)) { endpoint in
                    historyRow(endpoint)
                }
                if viewModel.history.count > 20 {
                    Button(action: { showingAllHistory = true }) {
                        Text("Show \(viewModel.history.count - 20) more...")
                            .font(.system(size: 11))
                            .foregroundColor(.accentBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func historyRow(_ endpoint: HTTPEndpoint) -> some View {
        HStack(spacing: 6) {
            methodBadge(endpoint.request.method)

            Text(endpoint.name.isEmpty ? endpoint.request.url : endpoint.name)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            openEndpoint(endpoint)
        }
        .draggable(endpoint.id)
    }

    // MARK: - Actions

    private func openEndpoint(_ endpoint: HTTPEndpoint) {
        if let existing = editorVM.tabs.first(where: { $0.restApiRequestId == endpoint.id }) {
            editorVM.activeTabId = existing.id
            return
        }
        let tab = Tab(
            name: endpoint.name.isEmpty ? endpoint.request.method.rawValue : endpoint.name,
            type: .restApi,
            restApiRequestId: endpoint.id
        )
        editorVM.tabs.append(tab)
        editorVM.activeTabId = tab.id
        editorVM.saveTabsToWorktree()
    }

    private func openNewTab() {
        let tab = Tab(
            name: "REST API",
            type: .restApi,
            restApiRequestId: nil
        )
        editorVM.tabs.append(tab)
        editorVM.activeTabId = tab.id
        editorVM.saveTabsToWorktree()
    }

    private func handleDrop(_ providers: [NSItemProvider], to collection: EndpointCollection) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
                if let data = data as? Data, let endpointId = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        if let endpoint = self.findEndpoint(by: endpointId) {
                            viewModel.endpointStore.moveEndpoint(endpoint, to: collection.id)
                        }
                    }
                }
            }
        }
        return true
    }

    private func findEndpoint(by id: String) -> HTTPEndpoint? {
        for collection in viewModel.collections {
            if let endpoint = collection.endpoints.first(where: { $0.id == id }) {
                return endpoint
            }
        }
        return viewModel.history.first { $0.id == id }
    }

    private var newCollectionSheet: some View {
        VStack(spacing: 16) {
            Text("New Collection")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)

            TextField("Collection name", text: $viewModel.newCollectionName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.newCollectionName = ""
                    viewModel.showNewCollectionSheet = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    let collection = EndpointCollection(name: viewModel.newCollectionName)
                    viewModel.endpointStore.addCollection(collection)
                    viewModel.newCollectionName = ""
                    viewModel.showNewCollectionSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.newCollectionName.isEmpty)
            }
        }
        .padding(20)
        .background(Color.bgSecondary)
    }

    private var renameCollectionSheet: some View {
        VStack(spacing: 16) {
            Text("Rename Collection")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)

            TextField("Collection name", text: $renamingCollectionName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    renamingCollectionId = nil
                    renamingCollectionName = ""
                    showRenameCollectionSheet = false
                }
                .buttonStyle(.bordered)

                Button("Rename") {
                    if let id = renamingCollectionId,
                       let index = viewModel.collections.firstIndex(where: { $0.id == id }) {
                        viewModel.endpointStore.collections[index].name = renamingCollectionName
                        viewModel.endpointStore.save()
                    }
                    renamingCollectionId = nil
                    renamingCollectionName = ""
                    showRenameCollectionSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renamingCollectionName.isEmpty)
            }
        }
        .padding(20)
        .background(Color.bgSecondary)
    }

    private var allHistorySheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button(action: { showingAllHistory = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.bgSecondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.history) { endpoint in
                        historyRow(endpoint)
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .background(Color.bgPrimary)
    }

    private var renameEndpointSheet: some View {
        VStack(spacing: 16) {
            Text("Rename Request")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)

            TextField("Request name", text: $renameEndpointName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    endpointToRename = nil
                    renameEndpointName = ""
                    showRenameEndpoint = false
                }
                .buttonStyle(.bordered)

                Button("Rename") {
                    if let endpoint = endpointToRename {
                        var updated = endpoint
                        updated.name = renameEndpointName
                        viewModel.endpointStore.updateEndpoint(updated)
                    }
                    endpointToRename = nil
                    renameEndpointName = ""
                    showRenameEndpoint = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameEndpointName.isEmpty)
            }
        }
        .padding(20)
        .background(Color.bgSecondary)
    }
}
