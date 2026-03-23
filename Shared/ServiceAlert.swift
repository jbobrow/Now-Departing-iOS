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
    /// All time windows during which this alert is active.
    /// Empty means the alert has no time restriction (always active).
    let activePeriods: [(start: Date?, end: Date?)]

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

    // MARK: - Active period helpers

    /// The next period that is currently active or upcoming, chronologically.
    var nextActivePeriod: (start: Date?, end: Date?)? {
        let now = Date()
        return activePeriods
            .filter { p in
                // Keep if no end (open-ended) or end is in the future
                p.end.map { $0 > now } ?? true
            }
            .sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
            .first
    }

    /// True when the alert has an active period that contains the current time.
    var isCurrentlyActive: Bool {
        guard !activePeriods.isEmpty else { return true }
        let now = Date()
        return activePeriods.contains { p in
            let afterStart = p.start.map { $0 <= now } ?? true
            let beforeEnd  = p.end.map   { $0 > now  } ?? true
            return afterStart && beforeEnd
        }
    }

    /// Human-readable timing summary, e.g. "Until Mon 5:00 AM" or "Fri 11:45 PM – Sat 5:00 AM".
    /// Returns nil if there are no time restrictions or the summary can't be meaningfully formed.
    var activePeriodSummary: String? {
        guard let period = nextActivePeriod else { return nil }
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE h:mm a"

        let started = period.start.map { $0 <= now } ?? true
        if started {
            guard let end = period.end else { return nil }
            return "Until \(fmt.string(from: end))"
        } else if let start = period.start {
            var s = fmt.string(from: start)
            if let end = period.end {
                s += " – \(fmt.string(from: end))"
            }
            return s
        }
        return nil
    }
}

// MARK: - Manager

final class ServiceAlertsManager: ObservableObject {
    @Published private(set) var alertsByRoute: [String: [ServiceAlert]] = [:]

    private var lastFetchTime: Date?
    private let cacheTTL: TimeInterval = 60  // 1 minute

    func fetchAlerts() {
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < cacheTTL {
            return
        }
        print("[ServiceAlerts] starting network fetch…")

        MTAFeedService.shared.fetchServiceAlerts { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("[ServiceAlerts] Fetch failed: \(error)")
            case .success(let gtfsAlerts):
                print("[ServiceAlerts] Fetched \(gtfsAlerts.count) raw alerts from feed")
                // Process and deduplicate on a background thread.
                DispatchQueue.global(qos: .userInitiated).async {
                    let byRoute = Self.buildAlertsByRoute(gtfsAlerts)
                    print("[ServiceAlerts] Deduplicated alertsByRoute keys: \(byRoute.keys.sorted())")
                    DispatchQueue.main.async {
                        self.alertsByRoute = byRoute
                        self.lastFetchTime = Date()
                    }
                }
            }
        }
    }

    func alerts(for routeId: String) -> [ServiceAlert] {
        return alertsByRoute[routeId] ?? []
    }

    func hasAlerts(for routeId: String) -> Bool {
        return !(alertsByRoute[routeId]?.isEmpty ?? true)
    }

    // MARK: - Private processing

    /// Converts raw GTFSAlerts into ServiceAlerts grouped by route ID.
    /// Deduplicates alerts with the same headerText by merging their active periods.
    /// Drops alerts whose every time window is already in the past.
    private static func buildAlertsByRoute(_ gtfsAlerts: [GTFSAlert]) -> [String: [ServiceAlert]] {
        // Key: routeId → (headerText → accumulated data)
        struct Accumulator {
            var effect: Int
            var descriptionText: String
            var routeIds: [String]
            var activePeriods: [(start: Date?, end: Date?)]
        }

        var perRoute: [String: [String: Accumulator]] = [:]  // [routeId: [headerText: Accumulator]]

        for gtfsAlert in gtfsAlerts {
            guard !gtfsAlert.headerText.isEmpty, !gtfsAlert.routeIds.isEmpty else { continue }

            for routeId in Set(gtfsAlert.routeIds) {
                let key = gtfsAlert.headerText
                if perRoute[routeId] == nil { perRoute[routeId] = [:] }

                if var acc = perRoute[routeId]![key] {
                    // Merge active periods from duplicate alert entries
                    acc.activePeriods.append(contentsOf: gtfsAlert.activePeriods)
                    perRoute[routeId]![key] = acc
                } else {
                    perRoute[routeId]![key] = Accumulator(
                        effect: gtfsAlert.effect,
                        descriptionText: gtfsAlert.descriptionText,
                        routeIds: gtfsAlert.routeIds,
                        activePeriods: gtfsAlert.activePeriods
                    )
                }
            }
        }

        let now = Date()
        var byRoute: [String: [ServiceAlert]] = [:]

        for (routeId, headerMap) in perRoute {
            let alerts: [ServiceAlert] = headerMap.compactMap { (header, acc) in
                // Drop alerts where every period has already ended
                if !acc.activePeriods.isEmpty {
                    let hasCurrentOrFuture = acc.activePeriods.contains { p in
                        p.end.map { $0 > now } ?? true
                    }
                    guard hasCurrentOrFuture else { return nil }
                }

                return ServiceAlert(
                    id: "\(routeId)-\(header.hashValue)",
                    routeIds: acc.routeIds,
                    headerText: header,
                    descriptionText: acc.descriptionText,
                    effect: ServiceAlert.AlertEffect(rawValue: acc.effect) ?? .other,
                    activePeriods: acc.activePeriods
                )
            }
            // Sort: currently-active alerts first, then by next start time
            .sorted { a, b in
                if a.isCurrentlyActive != b.isCurrentlyActive {
                    return a.isCurrentlyActive
                }
                let aStart = a.nextActivePeriod?.start ?? .distantPast
                let bStart = b.nextActivePeriod?.start ?? .distantPast
                return aStart < bStart
            }

            if !alerts.isEmpty {
                byRoute[routeId] = alerts
            }
        }

        return byRoute
    }
}
