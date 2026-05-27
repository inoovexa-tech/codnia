import Foundation

public struct EnvironmentVariable: Codable, Identifiable, Equatable {
    public let id: String
    public var key: String
    public var value: String
    public var isSecret: Bool

    public init(id: String = UUID().uuidString, key: String, value: String, isSecret: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.isSecret = isSecret
    }
}

public struct APIEnvironment: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var variables: [EnvironmentVariable]
    public var isActive: Bool

    public init(id: String = UUID().uuidString, name: String, variables: [EnvironmentVariable] = [], isActive: Bool = false) {
        self.id = id
        self.name = name
        self.variables = variables
        self.isActive = isActive
    }

    public func resolve(_ text: String) -> String {
        var result = text
        for variable in variables {
            let placeholder = "{{\(variable.key)}}"
            result = result.replacingOccurrences(of: placeholder, with: variable.value)
        }
        return result
    }

    public func value(for key: String) -> String? {
        variables.first { $0.key == key }?.value
    }
}

public final class EnvironmentStore: ObservableObject {
    @Published public var environments: [APIEnvironment] = []

    private let fileURL: URL

    public init(directoryURL: URL) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        self.fileURL = directoryURL.appendingPathComponent("environments.json")
        load()
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            environments = [
                APIEnvironment(name: "Development", isActive: true),
                APIEnvironment(name: "Production", isActive: false)
            ]
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            environments = try JSONDecoder().decode([APIEnvironment].self, from: data)
        } catch {
            environments = [
                APIEnvironment(name: "Development", isActive: true),
                APIEnvironment(name: "Production", isActive: false)
            ]
            save()
        }
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(environments)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save environments: \(error)")
        }
    }

    public var activeEnvironment: APIEnvironment? {
        environments.first { $0.isActive }
    }

    public func activate(_ environment: APIEnvironment) {
        for i in environments.indices {
            environments[i].isActive = environments[i].id == environment.id
        }
        save()
    }

    public func addEnvironment(_ environment: APIEnvironment) {
        environments.append(environment)
        save()
    }

    public func removeEnvironment(_ environment: APIEnvironment) {
        environments.removeAll { $0.id == environment.id }
        save()
    }

    public func updateEnvironment(_ environment: APIEnvironment) {
        if let index = environments.firstIndex(where: { $0.id == environment.id }) {
            environments[index] = environment
            save()
        }
    }

    public func resolve(_ text: String) -> String {
        activeEnvironment?.resolve(text) ?? text
    }
}