import Foundation

enum Log {
    private static let path = "/tmp/codnia_debug.log"
    private static let lock = NSLock()

    static func clear() {
        lock.lock()
        try? FileManager.default.removeItem(atPath: path)
        lock.unlock()
    }

    static func write(_ msg: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(msg)\n"
        lock.lock()
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
        lock.unlock()
        fputs(line, stderr)
        fflush(stderr)
    }
}