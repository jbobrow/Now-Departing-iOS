//
//  ServiceAlert.swift
//  Now Departing
//
//  Model and manager for MTA service alerts (service changes).
//

import Combine
import Foundation

// MARK: - Model

struct ServiceAlert: Identifiable {
    let id: String
    let routeIds: [String]
    let headerText: String
    let descriptionText: String
    let effect: AlertEffect

    enum AlertEffect: Int {
        case noService = 1
        case reducedService = 2
        case significantDelays = 3
        case detour = 4
        case additionalService = 5
        case modifiedService = 6
        case other = 7
        case unknown = 0

        var displayText: String {
            switch self {
            case .noService: return "No Service"
            case .reducedService: return "Reduced Service"
            case .significantDelays: return "Significant Delays"
            case .detour: return "Detour"
            case .additionalService: return "Additional Service"
            case .modifiedService: return "Modified Service"
            default: return "Service Change"
            }
        }
    }
}

// MARK: - Manager

final class ServiceAlertsManager: ObservableObject {
    @Published private(set) var alertsByRoute: [String: [ServiceAlert]] = [:]

    private var lastFetchTime: Date?
    private let cacheTTL: TimeInterval = 60  // 1 minute

    func fetchAlerts() {
        // Don't refetch if cache is still fresh
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < cacheTTL {
            return
        }

        MTAFeedService.shared.fetchServiceAlerts { [weak self] result in
            guard let self = self else { return }
            if case .success(let gtfsAlerts) = result {
                var byRoute: [String: [ServiceAlert]] = [:]
                for (index, gtfsAlert) in gtfsAlerts.enumerated() {
                    guard !gtfsAlert.headerText.isEmpty else { continue }
                    let alert = ServiceAlert(
                        id: "\(index)-\(gtfsAlert.headerText.hashValue)",
                        routeIds: gtfsAlert.routeIds,
                        headerText: gtfsAlert.headerText,
                        descriptionText: gtfsAlert.descriptionText,
                        effect: ServiceAlert.AlertEffect(rawValue: gtfsAlert.effect) ?? .other
                    )
                    for routeId in gtfsAlert.routeIds {
                        byRoute[routeId, default: []].append(alert)
                    }
                }
                self.alertsByRoute = byRoute
                self.lastFetchTime = Date()
            }
        }
    }

    func alerts(for routeId: String) -> [ServiceAlert] {
        return alertsByRoute[routeId] ?? []
    }

    func hasAlerts(for routeId: String) -> Bool {
        return !(alertsByRoute[routeId]?.isEmpty ?? true)
    }
}
