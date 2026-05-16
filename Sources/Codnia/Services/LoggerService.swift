import Foundation

enum Log {
    private static let queue = DispatchQueue(label: "com.codnia.log")
    private static let path = "/tmp/codnia_debug.log"

    static func clear() {
        queue.sync { try? FileManager.default.removeItem(atPath: path) }
    }

    static func write(_ msg: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(msg)\n"
        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: path) {
                    if let fh = FileHandle(forWritingAtPath: path) {
                        fh.seekToEndOfFile()
                        fh.write(data)
                        try? fh.close()
                    }
                } else {
                    try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
                }
            }
        }
    }
}