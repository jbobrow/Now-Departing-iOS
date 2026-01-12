//
//  NavigationModels.swift
//  Now Departing
//
//  Shared navigation models for iOS and watchOS
//

import SwiftUI
import Combine

// MARK: - Navigation State (watchOS)

/// Navigation state manager for watchOS app
class NavigationState: ObservableObject {
    @Published var line: SubwayLine?
    @Published var station: Station?
    @Published var terminal: Station?
    @Published var direction: String?
    @Published var path = NavigationPath()

    func reset() {
        line = nil
        station = nil
        terminal = nil
        direction = nil
        path = NavigationPath()
    }
}

// MARK: - Navigation Route (iOS)

/// Navigation route for iOS LinesBrowseView
enum NavigationRoute: Hashable {
    case stations(SubwayLine)
    case terminals(SubwayLine, Station)
    case times(SubwayLine, Station, String)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .stations(let line):
            hasher.combine("stations")
            hasher.combine(line.id)
        case .terminals(let line, let station):
            hasher.combine("terminals")
            hasher.combine(line.id)
            hasher.combine(station.id)
        case .times(let line, let station, let direction):
            hasher.combine("times")
            hasher.combine(line.id)
            hasher.combine(station.id)
            hasher.combine(direction)
        }
    }

    static func == (lhs: NavigationRoute, rhs: NavigationRoute) -> Bool {
        switch (lhs, rhs) {
        case (.stations(let line1), .stations(let line2)):
            return line1.id == line2.id
        case (.terminals(let line1, let station1), .terminals(let line2, let station2)):
            return line1.id == line2.id && station1.id == station2.id
        case (.times(let line1, let station1, let dir1), .times(let line2, let station2, let dir2)):
            return line1.id == line2.id && station1.id == station2.id && dir1 == dir2
        default:
            return false
        }
    }
}

// MARK: - Deep Link Manager (iOS)

/// Manages deep linking from widgets to app
class DeepLinkManager: ObservableObject {
    @Published var activeLink: DeepLink?

    struct DeepLink: Equatable {
        let lineId: String
        let stationName: String
        let stationDisplay: String
        let direction: String
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "nowdeparting",
              url.host == "train",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }

        let lineId = queryItems.first(where: { $0.name == "lineId" })?.value
        let stationName = queryItems.first(where: { $0.name == "stationName" })?.value
        let stationDisplay = queryItems.first(where: { $0.name == "stationDisplay" })?.value
        let direction = queryItems.first(where: { $0.name == "direction" })?.value

        if let lineId = lineId, let stationName = stationName,
           let stationDisplay = stationDisplay, let direction = direction {
            activeLink = DeepLink(
                lineId: lineId,
                stationName: stationName,
                stationDisplay: stationDisplay,
                direction: direction
            )
        }
    }

    func clearLink() {
        activeLink = nil
    }
}
