import SwiftUI
import Combine

@MainActor
public final class RESTApiViewModel: ObservableObject {
    public let environmentStore: EnvironmentStore
    public let endpointStore: EndpointStore
    public let service: RESTApiService

    @Published public var collections: [EndpointCollection] = []
    @Published public var history: [HTTPEndpoint] = []

    @Published public var showEnvironmentEditor: Bool = false
    @Published public var showSaveSheet: Bool = false
    @Published public var showCollectionPicker: Bool = false
    @Published public var showNewCollectionSheet: Bool = false
    @Published public var newCollectionName: String = ""

    @Published public var saveEndpointName: String = ""

    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.environmentStore = EnvironmentStore.shared
        self.endpointStore = EndpointStore.shared
        self.service = RESTApiService(environmentStore: environmentStore, endpointStore: endpointStore)

        self.collections = endpointStore.collections
        self.history = endpointStore.history

        endpointStore.$collections.receive(on: DispatchQueue.main).sink { [weak self] cols in
            self?.collections = cols
        }.store(in: &cancellables)

        endpointStore.$history.receive(on: DispatchQueue.main).sink { [weak self] hist in
            self?.history = hist
        }.store(in: &cancellables)
    }

    public var activeEnvironment: APIEnvironment? {
        environmentStore.activeEnvironment
    }

    public func saveCurrentAsEndpoint(to collectionId: String?) {
        guard !saveEndpointName.isEmpty else { return }

        let endpoint = HTTPEndpoint(
            name: saveEndpointName,
            request: service.currentRequest,
            collectionId: collectionId
        )

        if let collectionId = collectionId {
            endpointStore.addEndpoint(endpoint, to: collectionId)
        }

        saveEndpointName = ""
        showSaveSheet = false
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