import Foundation

@MainActor
public final class RESTApiService: ObservableObject {
    @Published public var currentRequest: HTTPRequest = HTTPRequest()
    @Published public var currentResponse: HTTPResponse?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    @Published public var selectedTab: RequestTab = .params
    @Published public var responseTab: ResponseTab = .body

    public enum RequestTab: String, CaseIterable, Identifiable {
        case params = "Params"
        case headers = "Headers"
        case body = "Body"
        case auth = "Auth"

        public var id: String { rawValue }
    }

    public enum ResponseTab: String, CaseIterable, Identifiable {
        case body = "Body"
        case headers = "Headers"

        public var id: String { rawValue }
    }

    private let environmentStore: EnvironmentStore
    private let endpointStore: EndpointStore

    public init(environmentStore: EnvironmentStore, endpointStore: EndpointStore) {
        self.environmentStore = environmentStore
        self.endpointStore = endpointStore
    }

    public func execute() async {
        guard let url = currentRequest.buildURL(env: environmentStore.activeEnvironment) else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil
        currentResponse = nil

        var request = URLRequest(url: url)
        request.httpMethod = currentRequest.method.rawValue

        let headers = currentRequest.buildHeaders(env: environmentStore.activeEnvironment)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = currentRequest.buildBody(env: environmentStore.activeEnvironment) {
            request.httpBody = body
            if currentRequest.body.type == .json && headers["Content-Type"] == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } else if currentRequest.body.type == .formData && headers["Content-Type"] == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }

        let startTime = Date()

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
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

            let endpoint = HTTPEndpoint(
                name: "\(currentRequest.method.rawValue) \(url.path)",
                request: currentRequest
            )
            endpointStore.addToHistory(endpoint)

            currentResponse = HTTPResponse(
                request: currentRequest,
                statusCode: httpResponse.statusCode,
                statusMessage: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                headers: responseHeaders,
                body: data,
                timing: timing
            )

        } catch {
            errorMessage = error.localizedDescription
            let timing = Date().timeIntervalSince(startTime)
            currentResponse = HTTPResponse(
                request: currentRequest,
                statusCode: 0,
                statusMessage: "Error",
                headers: [:],
                body: Data(),
                timing: timing
            )
        }

        isLoading = false
    }

    public func loadEndpoint(_ endpoint: HTTPEndpoint) {
        currentRequest = endpoint.request
    }

    public func reset() {
        currentRequest = HTTPRequest()
        currentResponse = nil
        errorMessage = nil
        selectedTab = .params
        responseTab = .body
    }

    public func addHeader() {
        currentRequest.headers.append(KeyValuePair())
    }

    public func removeHeader(at index: Int) {
        guard currentRequest.headers.indices.contains(index) else { return }
        currentRequest.headers.remove(at: index)
    }

    public func addQueryParam() {
        currentRequest.queryParams.append(KeyValuePair())
    }

    public func removeQueryParam(at index: Int) {
        guard currentRequest.queryParams.indices.contains(index) else { return }
        currentRequest.queryParams.remove(at: index)
    }

    public func addFormField() {
        currentRequest.body.formData.append(KeyValuePair())
    }

    public func removeFormField(at index: Int) {
        guard currentRequest.body.formData.indices.contains(index) else { return }
        currentRequest.body.formData.remove(at: index)
    }
}