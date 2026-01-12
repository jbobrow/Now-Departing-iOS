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

    // Custom coding to handle missing "id" in JSON
    private enum CodingKeys: String, CodingKey {
        case display
        case name
        case hasAvailableTimes
        // Note: "id" is NOT in CodingKeys, so it won't be decoded from JSON
        // It will be auto-generated via init() when decoding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.display = try container.decode(String.self, forKey: .display)
        self.name = try container.decode(String.self, forKey: .name)
        self.hasAvailableTimes = try container.decodeIfPresent(Bool.self, forKey: .hasAvailableTimes)
        // Generate a stable ID based on the name to ensure consistency
        self.id = name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(display, forKey: .display)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(hasAvailableTimes, forKey: .hasAvailableTimes)
        // Note: "id" is not encoded, as it's derived from "name"
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
