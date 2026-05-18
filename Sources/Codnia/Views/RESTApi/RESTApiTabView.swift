import SwiftUI

struct RESTApiTabView: View {
    let tabId: String
    let restApiRequestId: String?
    @EnvironmentObject var editorVM: EditorViewModel

    @State private var request: HTTPRequest = HTTPRequest()
    @State private var response: HTTPResponse?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedTab: RequestTab = .params
    @State private var responseTab: ResponseTab = .body
    @State private var requestName: String = "New Request"
    @State private var isEditingName: Bool = false
    @State private var currentEndpointId: String?
    @State private var showSaveSheet: Bool = false
    @State private var selectedCollectionId: String?

    enum RequestTab: String, CaseIterable, Identifiable {
        case params = "Params"
        case headers = "Headers"
        case body = "Body"
        case auth = "Auth"

        var id: String { rawValue }
    }

    enum ResponseTab: String, CaseIterable, Identifiable {
        case body = "Body"
        case headers = "Headers"

        var id: String { rawValue }
    }

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
        .onAppear { loadEndpointIfNeeded() }
        .sheet(isPresented: $showSaveSheet) {
            saveSheet
        }
    }

    private func loadEndpointIfNeeded() {
        guard let requestId = restApiRequestId else { return }
        let store = EndpointStore.shared
        for collection in store.collections {
            if let endpoint = collection.endpoints.first(where: { $0.id == requestId }) {
                request = endpoint.request
                requestName = endpoint.name
                currentEndpointId = endpoint.id
                return
            }
        }
        if let endpoint = store.history.first(where: { $0.id == requestId }) {
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
        selectedCollectionId = EndpointStore.shared.collections.first?.id
        DispatchQueue.main.async {
            self.showSaveSheet = true
        }
    }

    private func saveToCollection(_ collectionId: String) {
        let store = EndpointStore.shared
        let endpointId = currentEndpointId ?? restApiRequestId
        if let endpointId {
            let updated = HTTPEndpoint(
                id: endpointId,
                name: requestName,
                request: request
            )
            store.updateEndpoint(updated)
        } else {
            let endpoint = HTTPEndpoint(
                name: requestName,
                request: request
            )
            store.addEndpoint(endpoint, to: collectionId)
            currentEndpointId = endpoint.id
        }
        store.addToHistory(HTTPEndpoint(name: requestName, request: request))
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

                ForEach(EndpointStore.shared.collections) { collection in
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
                selectedCollectionId = EndpointStore.shared.collections.first?.id
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
                ProgressView()
                    .scaleEffect(0.5)
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
            ForEach(RequestTab.allCases) { tab in
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
            if pairs.wrappedValue.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("No \(placeholder.lowercased())")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                        Button(action: { pairs.wrappedValue.append(KeyValuePair()) }) {
                            Text("Add")
                                .font(.system(size: 10))
                                .foregroundColor(.accentBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(pairs.wrappedValue.enumerated()), id: \.element.id) { index, pair in
                            keyValueRow(index: index, pairs: pairs)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .background(Color.bgPrimary)
    }

    private func keyValueRow(index: Int, pairs: Binding<[KeyValuePair]>) -> some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { pairs.wrappedValue[index].enabled },
                set: { pairs.wrappedValue[index].enabled = $0 }
            ))
            .toggleStyle(.checkbox)
            .scaleEffect(0.75)

            TextField("Key", text: Binding(
                get: { pairs.wrappedValue[index].key },
                set: { pairs.wrappedValue[index].key = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.bgTertiary)
            .cornerRadius(3)

            TextField("Value", text: Binding(
                get: { pairs.wrappedValue[index].value },
                set: { pairs.wrappedValue[index].value = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.bgTertiary)
            .cornerRadius(3)

            Button(action: { pairs.wrappedValue.remove(at: index) }) {
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
                .frame(maxHeight: 100)
                .padding(.horizontal, 8)
            } else if request.body.type == .formData {
                keyValueEditor(pairs: $request.body.formData, placeholder: "Form Data")
            }
        }
        .frame(maxHeight: 150)
    }

    private var authEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
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

    private var responseHeader: some View {
        Group {
            if let resp = response {
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

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.accentRed)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.bgTertiary)
            }
        }
    }

    private var responseTabs: some View {
        HStack(spacing: 0) {
            ForEach(ResponseTab.allCases) { tab in
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let prettyJSON = resp.bodyPrettyJSON {
                        Text(prettyJSON)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    } else if resp.bodyString.isEmpty {
                        Text("Empty response body")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                            .padding(8)
                    } else {
                        Text(resp.bodyString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
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

    private func executeRequest() {
        guard let url = request.buildURL(env: EnvironmentStore.shared.activeEnvironment) else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil
        response = nil

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        let headers = request.buildHeaders(env: EnvironmentStore.shared.activeEnvironment)
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let bodyData = request.buildBody(env: EnvironmentStore.shared.activeEnvironment) {
            urlRequest.httpBody = bodyData
            if request.body.type == .json && headers["Content-Type"] == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } else if request.body.type == .formData && headers["Content-Type"] == nil {
                urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }

        let startTime = Date()

        Task {
            do {
                let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)
                let timing = Date().timeIntervalSince(startTime)

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

            let historyEndpoint = HTTPEndpoint(name: requestName, request: request)
            EndpointStore.shared.addToHistory(historyEndpoint)
        }
    }
}