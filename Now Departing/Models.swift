//
//  Models.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

struct SubwayLine: Identifiable, Equatable {
    let id: String
    let label: String
    let bg_color: Color
    let fg_color: Color
}

struct Station: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    let display: String
    let name: String
    var hasAvailableTimes: Bool?
}

// Copy the API response models from your WatchOS app
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
