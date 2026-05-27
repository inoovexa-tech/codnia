import SwiftUI
import Combine

@MainActor
public final class RESTApiViewModel: ObservableObject {
    @Published public var environmentStore: EnvironmentStore
    @Published public var endpointStore: EndpointStore

    @Published public var collections: [EndpointCollection] = []
    @Published public var history: [HTTPEndpoint] = []

    @Published public var selectedCollectionId: String?

    @Published public var showEnvironmentEditor: Bool = false
    @Published public var showNewCollectionSheet: Bool = false
    @Published public var newCollectionName: String = ""

    private var cancellables = Set<AnyCancellable>()

    public static func directoryURL(for projectPath: String?) -> URL {
        if let projectPath {
            return URL(fileURLWithPath: projectPath).appendingPathComponent(".codnia/restapi")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Codnia/restapi")
    }

    public init(projectPath: String?) {
        let dir = Self.directoryURL(for: projectPath)
        Self.migrateGlobalDataIfNeeded(to: dir)
        let envStore = EnvironmentStore(directoryURL: dir)
        let epStore = EndpointStore(directoryURL: dir)
        self.environmentStore = envStore
        self.endpointStore = epStore

        self.collections = epStore.collections
        self.history = epStore.history

        subscribeToStores()
    }

    public func reloadForProject(projectPath: String?) {
        cancellables.removeAll()
        let dir = Self.directoryURL(for: projectPath)
        Self.migrateGlobalDataIfNeeded(to: dir)
        let envStore = EnvironmentStore(directoryURL: dir)
        let epStore = EndpointStore(directoryURL: dir)
        environmentStore = envStore
        endpointStore = epStore
        collections = epStore.collections
        history = epStore.history
        subscribeToStores()
    }

    private func subscribeToStores() {
        endpointStore.$collections.receive(on: DispatchQueue.main).sink { [weak self] cols in
            self?.collections = cols
        }.store(in: &cancellables)

        endpointStore.$history.receive(on: DispatchQueue.main).sink { [weak self] hist in
            self?.history = hist
        }.store(in: &cancellables)
    }

    private static func migrateGlobalDataIfNeeded(to directoryURL: URL) {
        guard !FileManager.default.fileExists(atPath: directoryURL.path) else { return }
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let oldDir = appSupport.appendingPathComponent("Codnia")
        guard fm.fileExists(atPath: oldDir.path) else { return }
        try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        for file in ["endpoints.json", "history.json", "environments.json"] {
            let src = oldDir.appendingPathComponent(file)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: directoryURL.appendingPathComponent(file))
            }
        }
    }

    public var activeEnvironment: APIEnvironment? {
        environmentStore.activeEnvironment
    }

    public func deleteEnvironment(_ environment: APIEnvironment) {
        environmentStore.removeEnvironment(environment)
    }

    public func addEnvironment(name: String) {
        let env = APIEnvironment(name: name)
        environmentStore.addEnvironment(env)
    }

    public func selectEnvironment(_ environment: APIEnvironment) {
        environmentStore.activate(environment)
        objectWillChange.send()
    }
}

// MARK: - REST API Tab State (persists across tab switches)

enum RESTApiRequestTab: String, CaseIterable, Identifiable {
    case params = "Params"
    case headers = "Headers"
    case body = "Body"
    case auth = "Auth"
    var id: String { rawValue }
}

enum RESTApiResponseTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case headers = "Headers"
    var id: String { rawValue }
}

struct RESTApiTabState {
    var request: HTTPRequest = HTTPRequest()
    var response: HTTPResponse? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var selectedTab: RESTApiRequestTab = .params
    var responseTab: RESTApiResponseTab = .body
    var requestName: String = "New Request"
    var isEditingName: Bool = false
    var currentEndpointId: String? = nil
    var showSaveSheet: Bool = false
    var selectedCollectionId: String? = nil
}