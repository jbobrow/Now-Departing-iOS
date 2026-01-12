//
//  NavigationModels.swift
//  Now Departing
//
//  Shared navigation models for iOS and watchOS
//

import SwiftUI

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
