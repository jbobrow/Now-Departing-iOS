//
//  SharedModels.swift
//  Now Departing
//
//  Shared data models used across iOS, watchOS, and Widget targets
//

import SwiftUI

// MARK: - Subway Line Model

struct SubwayLine: Identifiable, Equatable, Hashable {
    let id: String
    let label: String
    let bg_color: Color
    let fg_color: Color

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SubwayLine, rhs: SubwayLine) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Station Model

struct Station: Identifiable, Codable, Equatable {
    let id: String
    let display: String
    let name: String
    var hasAvailableTimes: Bool?

    init(id: String = UUID().uuidString, display: String, name: String, hasAvailableTimes: Bool? = nil) {
        self.id = id
        self.display = display
        self.name = name
        self.hasAvailableTimes = hasAvailableTimes
    }

    private enum CodingKeys: String, CodingKey {
        case display
        case name
        case id
        case hasAvailableTimes
    }
}

// MARK: - API Response Models

struct APIResponse: Decodable {
    let data: [StationData]
}

struct StationData: Decodable {
    let name: String
    let N: [Train]
    let S: [Train]
}

struct Train: Decodable {
    let route: String
    let time: String
}
