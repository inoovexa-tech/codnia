import Foundation

struct BrowserNetworkTiming: Equatable {
    let blocked: Double
    let dns: Double
    let connect: Double
    let tls: Double
    let request: Double
    let response: Double

    var total: Double {
        blocked + dns + connect + tls + request + response
    }

    var startOffset: Double {
        blocked
    }

    static func fromResourceTiming(_ entries: [[String: Any]]) -> [String: BrowserNetworkTiming] {
        var result: [String: BrowserNetworkTiming] = [:]
        for entry in entries {
            guard
                let name = entry["name"] as? String,
                let startTime = entry["startTime"] as? Double,
                let duration = entry["duration"] as? Double,
                let initiatorType = entry["initiatorType"] as? String
            else { continue }

            let dns = entry["domainLookupEnd"] as? Double ?? 0 - (entry["domainLookupStart"] as? Double ?? 0)
            let connect = entry["connectEnd"] as? Double ?? 0 - (entry["connectStart"] as? Double ?? 0)
            let tls = entry["secureConnectionStart"] as? Double ?? 0 > 0
                ? (entry["connectEnd"] as? Double ?? 0) - (entry["secureConnectionStart"] as? Double ?? 0)
                : 0
            let request = entry["responseStart"] as? Double ?? 0 - (entry["requestStart"] as? Double ?? 0)
            let response = entry["responseEnd"] as? Double ?? 0 - (entry["responseStart"] as? Double ?? 0)
            let blocked = startTime > 0 ? startTime : 0

            result[name] = BrowserNetworkTiming(
                blocked: blocked,
                dns: max(dns, 0),
                connect: max(connect, 0),
                tls: max(tls, 0),
                request: max(request, 0),
                response: max(response, 0)
            )
        }
        return result
    }
}
