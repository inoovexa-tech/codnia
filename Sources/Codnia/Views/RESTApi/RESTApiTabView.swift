import SwiftUI

struct RESTApiTabView: View {
    let tabId: String
    let restApiRequestId: String?
    let endpointStore: EndpointStore
    let environmentStore: EnvironmentStore
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var request: HTTPRequest = HTTPRequest()
    @State private var response: HTTPResponse?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedTab: RESTApiRequestTab = .params
    @State private var responseTab: RESTApiResponseTab = .body
    @State private var requestName: String = "New Request"
    @State private var isEditingName: Bool = false
    @State private var currentEndpointId: String?
    @State private var showSaveSheet: Bool = false
    @State private var selectedCollectionId: String?
    @State private var currentTask: Task<Void, Never>?
    @State private var searchResponseText: String = ""
    @State private var showResponseSearch: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            requestBar
            requestTabs
            requestContent
            if response != nil {
                Divider().background(Color.borderDefault)
                responseHeader
                responseTabs
                responseContent
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgPrimary)
        .onAppear { restoreState() }
        .onDisappear { saveState() }
        .sheet(isPresented: $showSaveSheet) {
            saveSheet
        }
    }

    private func restoreState() {
        if let saved = editorVM.restApiTabStates[tabId] {
            request = saved.request
            response = saved.response
            isLoading = saved.isLoading
            errorMessage = saved.errorMessage
            selectedTab = saved.selectedTab
            responseTab = saved.responseTab
            requestName = saved.requestName
            isEditingName = saved.isEditingName
            currentEndpointId = saved.currentEndpointId
            showSaveSheet = saved.showSaveSheet
            selectedCollectionId = saved.selectedCollectionId
        } else if let requestId = restApiRequestId {
            loadEndpoint(requestId)
        }
    }

    private func saveState() {
        editorVM.restApiTabStates[tabId] = RESTApiTabState(
            request: request,
            response: response,
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedTab: selectedTab,
            responseTab: responseTab,
            requestName: requestName,
            isEditingName: isEditingName,
            currentEndpointId: currentEndpointId,
            showSaveSheet: showSaveSheet,
            selectedCollectionId: selectedCollectionId
        )
    }

    private func loadEndpoint(_ requestId: String) {
        for collection in endpointStore.collections {
            if let endpoint = collection.endpoints.first(where: { $0.id == requestId }) {
                request = endpoint.request
                requestName = endpoint.name
                currentEndpointId = endpoint.id
                return
            }
        }
        if let endpoint = endpointStore.history.first(where: { $0.id == requestId }) {
            request = endpoint.request
            requestName = endpoint.name
            currentEndpointId = endpoint.id
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            if isEditingName {
                TextField("Request name", text: $requestName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)
                    .onSubmit { isEditingName = false }
            } else {
                Text(requestName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .onTapGesture { isEditingName = true }
            }

            Spacer()

            Button(action: { saveRequest() }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10))
                    Text("Save")
                        .font(.system(size: 11))
                }
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bgTertiary)
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private func saveRequest() {
        guard !endpointStore.collections.isEmpty else {
            errorMessage = "No collections available. Create one in the sidebar first."
            return
        }
        selectedCollectionId = endpointStore.collections.first?.id
        DispatchQueue.main.async {
            self.showSaveSheet = true
        }
    }

    private func saveToCollection(_ collectionId: String) {
        let endpointId = currentEndpointId ?? restApiRequestId
        if let endpointId {
            let found = endpointStore.collections.contains { $0.endpoints.contains { $0.id == endpointId } }
            if found {
                let updated = HTTPEndpoint(
                    id: endpointId,
                    name: requestName,
                    request: request,
                    updatedAt: Date()
                )
                endpointStore.updateEndpoint(updated)
            } else {
                let endpoint = HTTPEndpoint(
                    name: requestName,
                    request: request,
                    collectionId: collectionId
                )
                endpointStore.addEndpoint(endpoint, to: collectionId)
                currentEndpointId = endpoint.id
            }
        } else {
            let endpoint = HTTPEndpoint(
                name: requestName,
                request: request,
                collectionId: collectionId
            )
            endpointStore.addEndpoint(endpoint, to: collectionId)
            currentEndpointId = endpoint.id
        }
        endpointStore.addToHistory(HTTPEndpoint(name: requestName, request: request))
        showSaveSheet = false
    }

    private var saveSheet: some View {
        VStack(spacing: 16) {
            Text("Save Request")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)

            TextField("Request name", text: $requestName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            VStack(alignment: .leading, spacing: 8) {
                Text("Collection:")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                ForEach(endpointStore.collections) { collection in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.textTertiary)
                        Text(collection.name)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if collection.id == selectedCollectionId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentGreen)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedCollectionId == collection.id ? Color.bgHover : Color.bgTertiary)
                    .cornerRadius(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCollectionId = collection.id
                    }
                }
            }
            .frame(width: 250)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showSaveSheet = false
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    if let cid = selectedCollectionId {
                        saveToCollection(cid)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .background(Color.bgSecondary)
        .onAppear {
            if selectedCollectionId == nil {
                selectedCollectionId = endpointStore.collections.first?.id
            }
        }
    }

    private var requestBar: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(HTTPMethod.allCases) { method in
                    Button(action: { request.method = method }) {
                        HStack {
                            Text(method.rawValue)
                            Spacer()
                            Circle()
                                .fill(methodColor(method))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(methodColor(request.method))
                        .frame(width: 8, height: 8)
                    Text(request.method.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(methodColor(request.method))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(methodColor(request.method).opacity(0.15))
                .cornerRadius(4)
            }
            .frame(width: 100)
            .padding(.leading, 8)

            TextField("Enter URL or paste text", text: $request.url)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.bgTertiary)
                .cornerRadius(4)
                .padding(.leading, 4)
                .padding(.trailing, 8)

            if !isLoading {
                Button(action: { executeRequest() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Send")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentGreen)
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
            } else {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Button(action: { cancelRequest() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.accentRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Cancel request")
                }
                .frame(width: 60, height: 28)
                .padding(.trailing, 8)
            }
        }
        .frame(height: 44)
        .background(Color.bgSecondary)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(.borderDefault),
            alignment: .bottom
        )
    }

    private var requestTabs: some View {
        HStack(spacing: 0) {
            ForEach(RESTApiRequestTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selectedTab == tab ? .textPrimary : .textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.bgHover : Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .background(Color.bgSecondary)
    }

    @ViewBuilder
    private var requestContent: some View {
        switch selectedTab {
        case .params:
            keyValueEditor(pairs: $request.queryParams, placeholder: "Query Parameters")
        case .headers:
            keyValueEditor(pairs: $request.headers, placeholder: "Headers")
        case .body:
            bodyEditor
        case .auth:
            authEditor
        }
    }

    private func keyValueEditor(pairs: Binding<[KeyValuePair]>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if pairs.wrappedValue.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Text("No \(placeholder.lowercased())")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(pairs.wrappedValue) { element in
                            let id = element.id
                            keyValueRow(
                                pair: Binding(
                                    get: { pairs.wrappedValue.first(where: { $0.id == id }) ?? element },
                                    set: { newValue in
                                        guard let idx = pairs.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
                                        pairs.wrappedValue[idx] = newValue
                                    }
                                ),
                                onDelete: {
                                    pairs.wrappedValue.removeAll { $0.id == id }
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            Button(action: { pairs.wrappedValue.append(KeyValuePair()) }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                    Text("Add \(placeholder)")
                        .font(.system(size: 10))
                }
                .foregroundColor(.accentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(Color.bgPrimary)
    }

    private func keyValueRow(pair: Binding<KeyValuePair>, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Toggle("", isOn: pair.enabled)
                .toggleStyle(.checkbox)
                .scaleEffect(0.75)

            TextField("Key", text: pair.key)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.bgTertiary)
                .cornerRadius(3)

            TextField("Value", text: pair.value)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.bgTertiary)
                .cornerRadius(3)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Body Type", selection: $request.body.type) {
                ForEach(RequestBodyType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.top, 8)

            if request.body.type == .json {
                HStack {
                    Button(action: formatJSONBody) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 10))
                        Text("Format")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.accentBlue)
                    .help("Pretty-print JSON")
                    Spacer()
                }
                .padding(.horizontal, 8)
            }

            if request.body.type == .json || request.body.type == .raw {
                TextEditor(text: Binding(
                    get: { request.body.type == .json ? request.body.jsonContent : request.body.rawContent },
                    set: { newValue in
                        if request.body.type == .json {
                            request.body.jsonContent = newValue
                        } else {
                            request.body.rawContent = newValue
                        }
                    }
                ))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.bgTertiary)
                .cornerRadius(4)
                .padding(.horizontal, 8)
            } else if request.body.type == .formData {
                keyValueEditor(pairs: $request.body.formData, placeholder: "Form Data")
            }
        }
    }

    private func formatJSONBody() {
        guard let data = request.body.jsonContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8)
        else { return }
        request.body.jsonContent = prettyString
    }

    private var authEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle("Enabled", isOn: $request.auth.enabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .help(request.auth.enabled ? "Auth is enabled" : "Auth is disabled")

                Text("Type:")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Picker("", selection: $request.auth.type) {
                    ForEach(AuthType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            if request.auth.enabled {
                switch request.auth.type {
                case .none:
                    Text("No authentication")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 8)

                case .basic:
                    authFieldRow(label: "Username", text: $request.auth.username, isSecure: false)
                    authFieldRow(label: "Password", text: $request.auth.password, isSecure: true)

                case .bearerToken:
                    authFieldRow(label: "Token", text: $request.auth.token, isSecure: false)

                case .apiKey:
                    authFieldRow(label: "Key Name", text: $request.auth.apiKeyName, isSecure: false)
                    authFieldRow(label: "Key Value", text: $request.auth.apiKeyValue, isSecure: false)
                    HStack(spacing: 8) {
                        Text("Add to:")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        Picker("", selection: $request.auth.apiKeyLocation) {
                            Text("Header").tag(AuthConfig.APIKeyLocation.header)
                            Text("Query Param").tag(AuthConfig.APIKeyLocation.queryParam)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                Text("Authentication is disabled")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, 8)
            }

            Spacer()
        }
    }

    private func authFieldRow(label: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 70, alignment: .trailing)

            if isSecure {
                SecureField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)
            } else {
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bgTertiary)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 8)
    }

    private var resolvedURLString: String {
        let env = environmentStore.activeEnvironment
        if let url = request.buildURL(env: env) {
            return url.absoluteString
        }
        return request.url
    }

    private var responseHeader: some View {
        Group {
            if let resp = response {
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(resp.statusCode)")
                                .font(.system(size: 11, weight: .bold))
                            Text(resp.statusMessage)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(statusColor(for: resp))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(for: resp).opacity(0.15))
                        .cornerRadius(4)

                        Text(resp.formattedTiming)
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)

                        Text(resp.formattedSize)
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)

                        Spacer()

                        if !resp.body.isEmpty {
                            Button(action: { copyResponse(resp) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text("Copy")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.textTertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.accentRed)
                        }
                    }

                    if resolvedURLString != request.url {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(.textTertiary)
                            Text(resolvedURLString)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.bgTertiary)
            }
        }
    }

    private func copyResponse(_ resp: HTTPResponse) {
        let text = resp.bodyPrettyJSON ?? resp.bodyString
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func jsonHighlightedText(_ json: String) -> Text {
        var result = Text("")
        let lines = json.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            var styledLine = Text("")
            var remaining = Substring(line)
            while !remaining.isEmpty {
                if remaining.hasPrefix("\"") {
                    let end = remaining.dropFirst().firstIndex(of: "\"")
                    if let endIdx = end {
                        let content = remaining[remaining.startIndex...endIdx]
                        let charAfter = remaining.index(after: endIdx)
                        let isKey = charAfter < remaining.endIndex && remaining[charAfter] == ":"
                        styledLine = styledLine + Text(content).foregroundColor(isKey ? .accentBlue : .accentGreen)
                        remaining = remaining[remaining.index(after: endIdx)...]
                    } else {
                        styledLine = styledLine + Text(remaining).foregroundColor(.textPrimary)
                        remaining = ""
                    }
                } else if remaining.hasPrefix("{") || remaining.hasPrefix("}") || remaining.hasPrefix("[") || remaining.hasPrefix("]") {
                    styledLine = styledLine + Text(String(remaining.first!)).foregroundColor(.textTertiary)
                    remaining = remaining.dropFirst()
                } else if remaining.hasPrefix(":") {
                    styledLine = styledLine + Text(":").foregroundColor(.textTertiary)
                    remaining = remaining.dropFirst()
                } else if remaining.hasPrefix(",") {
                    styledLine = styledLine + Text(",").foregroundColor(.textTertiary)
                    remaining = remaining.dropFirst()
                } else if remaining.hasPrefix("true") || remaining.hasPrefix("false") {
                    styledLine = styledLine + Text(remaining.prefix(5)).foregroundColor(.accentYellow)
                    remaining = remaining.dropFirst(remaining.hasPrefix("false") ? 5 : 4)
                } else if remaining.hasPrefix("null") {
                    styledLine = styledLine + Text("null").foregroundColor(.accentRed)
                    remaining = remaining.dropFirst(4)
                } else if remaining.first?.isNumber == true || remaining.first == "-" {
                    let numberEnd = remaining.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" || $0 == "e" || $0 == "E" })
                    styledLine = styledLine + Text(numberEnd).foregroundColor(.accentOrange)
                    remaining = remaining.dropFirst(numberEnd.count)
                } else {
                    styledLine = styledLine + Text(String(remaining.first!)).foregroundColor(.textPrimary)
                    remaining = remaining.dropFirst()
                }
            }
            result = result + styledLine
            if i < lines.count - 1 {
                result = result + Text("\n")
            }
        }
        return result
    }

    private var responseTabs: some View {
        HStack(spacing: 0) {
            ForEach(RESTApiResponseTab.allCases) { tab in
                Button(action: { responseTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(responseTab == tab ? .textPrimary : .textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
                .background(responseTab == tab ? Color.bgHover : Color.clear)
            }
            Spacer()
        }
        .background(Color.bgSecondary)
    }

    @ViewBuilder
    private var responseContent: some View {
        if responseTab == .body, let resp = response {
            VStack(spacing: 0) {
                if !resp.body.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                        TextField("Search in response...", text: $searchResponseText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.textPrimary)
                        if !searchResponseText.isEmpty {
                            Button(action: { searchResponseText = "" }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                                    .foregroundColor(.textTertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.bgSecondary)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if resp.body.isEmpty {
                            Text("Empty response body")
                                .font(.system(size: 12))
                                .foregroundColor(.textTertiary)
                                .padding(8)
                        } else if let prettyJSON = resp.bodyPrettyJSON {
                            if searchResponseText.isEmpty {
                                jsonHighlightedText(prettyJSON)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            } else {
                                jsonHighlightedText(prettyJSON, highlight: searchResponseText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                        } else {
                            let displayText = resp.bodyString
                            if searchResponseText.isEmpty {
                                Text(displayText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            } else {
                                highlightedText(displayText, query: searchResponseText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                            }
                        }
                    }
                }
            }
            .background(Color.bgTertiary)
            .cornerRadius(4)
            .padding(8)
        } else if responseTab == .headers, let resp = response {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(resp.headers.keys.sorted()), id: \.self) { key in
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentBlue)
                                .frame(width: 140, alignment: .trailing)

                            Text(resp.headers[key] ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(.textPrimary)

                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }
            .background(Color.bgTertiary)
            .cornerRadius(4)
            .padding(8)
        }
    }

    private func highlightedText(_ text: String, query: String) -> Text {
        guard !query.isEmpty else { return Text(text) }
        var result = Text("")
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            let searchRange = lowerText[currentIndex...]
            if let range = searchRange.range(of: lowerQuery) {
                let before = text[currentIndex..<range.lowerBound]
                if !before.isEmpty {
                    result = result + Text(String(before)).foregroundColor(.textPrimary)
                }
                result = result + Text(String(text[range])).foregroundColor(.accentYellow).bold()
                currentIndex = range.upperBound
            } else {
                let remaining = text[currentIndex...]
                result = result + Text(String(remaining)).foregroundColor(.textPrimary)
                break
            }
        }
        return result
    }

    private func jsonHighlightedText(_ json: String, highlight: String = "") -> Text {
        guard highlight.isEmpty else {
            return highlightedText(json, query: highlight)
        }
        var result = Text("")
        let lines = json.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            var styledLine = Text("")
            var remaining = Substring(line)
            while !remaining.isEmpty {
                if remaining.hasPrefix("\"") {
                    let afterQuote = remaining.dropFirst()
                    if let endIdx = afterQuote.firstIndex(of: "\"") {
                        let fullEnd = remaining.index(after: endIdx)
                        let content = remaining[remaining.startIndex...fullEnd]
                        let isKey = fullEnd < remaining.endIndex && remaining[remaining.index(after: fullEnd)] == ":"
                        styledLine = styledLine + Text(content).foregroundColor(isKey ? .accentBlue : .accentGreen)
                        remaining = remaining[remaining.index(after: fullEnd)...]
                    } else {
                        styledLine = styledLine + Text(remaining).foregroundColor(.textPrimary)
                        remaining = ""
                    }
                } else if remaining.hasPrefix("{") || remaining.hasPrefix("}") || remaining.hasPrefix("[") || remaining.hasPrefix("]") {
                    styledLine = styledLine + Text(String(remaining.first!)).foregroundColor(.textTertiary)
                    remaining = remaining.dropFirst()
                } else if remaining.hasPrefix(":") {
                    styledLine = styledLine + Text(":").foregroundColor(.textTertiary)
                    remaining = remaining.dropFirst()
                } else if remaining.hasPrefix(",") {
                    styledLine = styledLine + Text(",").foregroundColor(.textTertiary)
                    remaining = remaining.dropFirst()
                } else if remaining.hasPrefix("true") || remaining.hasPrefix("false") {
                    let word = remaining.hasPrefix("true") ? "true" : "false"
                    styledLine = styledLine + Text(word).foregroundColor(.accentYellow)
                    remaining = remaining.dropFirst(word.count)
                } else if remaining.hasPrefix("null") {
                    styledLine = styledLine + Text("null").foregroundColor(.accentRed)
                    remaining = remaining.dropFirst(4)
                } else if remaining.first?.isNumber == true || remaining.first == "-" {
                    let numberEnd = remaining.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" || $0 == "e" || $0 == "E" || $0 == "+" })
                    styledLine = styledLine + Text(numberEnd).foregroundColor(.accentOrange)
                    remaining = remaining.dropFirst(numberEnd.count)
                } else {
                    styledLine = styledLine + Text(String(remaining.first!)).foregroundColor(.textPrimary)
                    remaining = remaining.dropFirst()
                }
            }
            result = result + styledLine
            if i < lines.count - 1 {
                result = result + Text("\n")
            }
        }
        return result
    }

    private func statusColor(for resp: HTTPResponse) -> Color {
        switch resp.statusCategory {
        case .success: return .accentGreen
        case .redirect: return .accentYellow
        case .clientError: return .accentRed
        case .serverError: return .accentRed
        case .informational: return .accentBlue
        case .unknown: return .textTertiary
        }
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

    private func cancelRequest() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        errorMessage = "Request cancelled"
    }

    private func executeRequest() {
        guard let url = request.buildURL(env: environmentStore.activeEnvironment) else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil
        response = nil

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        let headers = request.buildHeaders(env: environmentStore.activeEnvironment)
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let bodyData = request.buildBody(env: environmentStore.activeEnvironment) {
            urlRequest.httpBody = bodyData
            if request.body.type == .json && headers["Content-Type"] == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } else if request.body.type == .formData && headers["Content-Type"] == nil {
                urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }

        let startTime = Date()

        currentTask = Task {
            do {
                let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)
                let timing = Date().timeIntervalSince(startTime)

                try Task.checkCancellation()

                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    errorMessage = "Invalid response"
                    isLoading = false
                    return
                }

                var responseHeaders: [String: String] = [:]
                for (key, value) in httpResponse.allHeaderFields {
                    if let keyString = key as? String, let valueString = value as? String {
                        responseHeaders[keyString] = valueString
                    }
                }

                response = HTTPResponse(
                    request: request,
                    statusCode: httpResponse.statusCode,
                    statusMessage: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    headers: responseHeaders,
                    body: data,
                    timing: timing
                )
            } catch is CancellationError {
                errorMessage = "Request cancelled"
                response = nil
            } catch {
                errorMessage = error.localizedDescription
                let timing = Date().timeIntervalSince(startTime)
                response = HTTPResponse(
                    request: request,
                    statusCode: 0,
                    statusMessage: "Error",
                    headers: [:],
                    body: Data(),
                    timing: timing
                )
            }

            isLoading = false
            currentTask = nil

            if errorMessage != "Request cancelled" {
                let historyEndpoint = HTTPEndpoint(name: requestName, request: request)
                endpointStore.addToHistory(historyEndpoint)
            }
        }
    }
}