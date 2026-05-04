//
//  WatchSyncManager.swift
//  Now Departing
//
//  Syncs favorites between the iOS app and watchOS companion via
//  WCSession.updateApplicationContext — a "latest wins" push that the
//  receiving side picks up on next activation.
//
//  Guarded by canImport(WatchConnectivity) so the widget extension,
//  which links neither WatchConnectivity nor this logic, compiles cleanly.
//

#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

class WatchSyncManager: NSObject {
    static let shared = WatchSyncManager()

    // Called on the main queue when the other device pushes a new favorites list.
    var onFavoritesReceived: (([FavoriteItem]) -> Void)?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(favorites: [FavoriteItem]) {
        guard WCSession.default.activationState == .activated,
              let encoded = try? JSONEncoder().encode(favorites) else { return }
        try? WCSession.default.updateApplicationContext(["favorites": encoded])
    }
}

extension WatchSyncManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["favorites"] as? Data,
              let favorites = try? JSONDecoder().decode([FavoriteItem].self, from: data)
        else { return }
        DispatchQueue.main.async { self.onFavoritesReceived?(favorites) }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    // iOS-only delegate requirements
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after the old session deactivates (e.g. watch swap)
        WCSession.default.activate()
    }
    #endif
}
#endif
