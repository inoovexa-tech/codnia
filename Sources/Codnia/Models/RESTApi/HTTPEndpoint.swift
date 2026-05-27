import Foundation

public struct HTTPEndpoint: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var request: HTTPRequest
    public var collectionId: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        request: HTTPRequest,
        collectionId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.request = request
        self.collectionId = collectionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct EndpointCollection: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var endpoints: [HTTPEndpoint]

    public init(id: String = UUID().uuidString, name: String, endpoints: [HTTPEndpoint] = []) {
        self.id = id
        self.name = name
        self.endpoints = endpoints
    }
}

public final class EndpointStore: ObservableObject {
    @Published public var collections: [EndpointCollection] = []
    @Published public var history: [HTTPEndpoint] = []

    private let fileURL: URL
    private let historyFileURL: URL

    public init(directoryURL: URL) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        self.fileURL = directoryURL.appendingPathComponent("endpoints.json")
        self.historyFileURL = directoryURL.appendingPathComponent("history.json")
        load()
        loadHistory()
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            collections = [EndpointCollection(name: "Default")]
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            collections = try JSONDecoder().decode([EndpointCollection].self, from: data)
            if collections.isEmpty {
                collections = [EndpointCollection(name: "Default")]
                save()
            }
        } catch {
            collections = [EndpointCollection(name: "Default")]
        }
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(collections)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save endpoints: \(error)")
        }
    }

    public func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            history = []
            return
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            history = try JSONDecoder().decode([HTTPEndpoint].self, from: data)
        } catch {
            history = []
        }
    }

    public func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    public func addToHistory(_ endpoint: HTTPEndpoint) {
        history.insert(endpoint, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        saveHistory()
    }

    public func addCollection(_ collection: EndpointCollection) {
        collections.append(collection)
        save()
    }

    public func removeCollection(_ collection: EndpointCollection) {
        collections.removeAll { $0.id == collection.id }
        save()
    }

    public func addEndpoint(_ endpoint: HTTPEndpoint, to collectionId: String) {
        if let index = collections.firstIndex(where: { $0.id == collectionId }) {
            collections[index].endpoints.append(endpoint)
            save()
        }
    }

    public func removeEndpoint(_ endpoint: HTTPEndpoint) {
        for i in collections.indices {
            collections[i].endpoints.removeAll { $0.id == endpoint.id }
        }
        save()
    }

    public func updateEndpoint(_ endpoint: HTTPEndpoint) {
        for i in collections.indices {
            if let j = collections[i].endpoints.firstIndex(where: { $0.id == endpoint.id }) {
                let original = collections[i].endpoints[j]
                var updated = endpoint
                updated.createdAt = original.createdAt
                updated.collectionId = original.collectionId
                updated.updatedAt = Date()
                collections[i].endpoints[j] = updated
                save()
                return
            }
        }
    }

    public func moveEndpoint(_ endpoint: HTTPEndpoint, to collectionId: String) {
        removeEndpoint(endpoint)
        var updated = endpoint
        updated.collectionId = collectionId
        addEndpoint(updated, to: collectionId)
    }
}