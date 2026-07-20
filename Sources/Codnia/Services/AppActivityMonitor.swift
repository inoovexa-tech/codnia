import Foundation
import AppKit
import Combine

@MainActor
final class AppActivityMonitor: ObservableObject {
    static let shared = AppActivityMonitor()

    @Published private(set) var isActive: Bool = true

    private var observers: [AnyObject] = []

    private init() {
        let nc = NotificationCenter.default

        let resignObserver = nc.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.isActive = false
        }

        let activateObserver = nc.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.isActive = true
        }

        observers = [resignObserver as AnyObject, activateObserver as AnyObject]
    }
}
