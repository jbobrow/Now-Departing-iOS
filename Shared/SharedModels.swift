//
//  SharedModels.swift
//  Now Departing
//
//  Shared data models used across iOS, watchOS, and Widget targets.
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
    /// GTFS parent stop ID (without direction suffix), e.g. "127" for Times Square
    /// on the 1/2/3 platforms.  Append "N" or "S" to get the directional stop ID
    /// used in GTFS-RT feeds.
    ///
    /// Populate this field by running `scripts/generate_gtfs_mapping.py` against
    /// the MTA's GTFS static data.  Stations without this value cannot be looked
    /// up in the GTFS-RT feed.
    var gtfsStopId: String?
    /// WGS-84 latitude from MTA GTFS `stops.txt`.  Required for the nearby-trains feature.
    var latitude: Double?
    /// WGS-84 longitude from MTA GTFS `stops.txt`.  Required for the nearby-trains feature.
    var longitude: Double?
    /// MTA complex ID grouping platforms that share an underground connection.
    /// Derived from the MTA's Stations.csv open data file via generate_gtfs_mapping.py.
    /// Used by the nearby view to merge same-complex platforms into one section.
    var complexId: String?
    var hasAvailableTimes: Bool?

    init(
        id: String = UUID().uuidString,
        display: String,
        name: String,
        gtfsStopId: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        complexId: String? = nil,
        hasAvailableTimes: Bool? = nil
    ) {
        self.id = id
        self.display = display
        self.name = name
        self.gtfsStopId = gtfsStopId
        self.latitude = latitude
        self.longitude = longitude
        self.complexId = complexId
        self.hasAvailableTimes = hasAvailableTimes
    }

    private enum CodingKeys: String, CodingKey {
        case display
        case name
        case gtfsStopId
        case latitude
        case longitude
        case complexId
        case hasAvailableTimes
        // "id" is intentionally omitted — it is derived from `name` on decode.
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.display = try container.decode(String.self, forKey: .display)
        self.name = try container.decode(String.self, forKey: .name)
        self.gtfsStopId = try container.decodeIfPresent(String.self, forKey: .gtfsStopId)
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        self.complexId = try container.decodeIfPresent(String.self, forKey: .complexId)
        self.hasAvailableTimes = try container.decodeIfPresent(Bool.self, forKey: .hasAvailableTimes)
        self.id = name  // stable, name-based ID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(display, forKey: .display)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(gtfsStopId, forKey: .gtfsStopId)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(complexId, forKey: .complexId)
        try container.encodeIfPresent(hasAvailableTimes, forKey: .hasAvailableTimes)
    }
}
