//
//  FavoriteItem.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/31/25.
//


import Foundation
import SwiftUI

// Defines the structure for a favorite item
struct FavoriteItem: Codable, Identifiable, Equatable {
    let id: String
    let lineId: String
    let stationName: String
    let stationDisplay: String
    let direction: String
    
    init(lineId: String, stationName: String, stationDisplay: String, direction: String) {
        self.id = UUID().uuidString
        self.lineId = lineId
        self.stationName = stationName
        self.stationDisplay = stationDisplay
        self.direction = direction
    }
}

// Manages favorite stations storage and operations
class FavoritesManager: ObservableObject {
    @Published private(set) var favorites: [FavoriteItem] = []
    private let favoritesKey = "savedFavorites"
    
    init() {
        loadFavorites()
    }
    
    // Load favorites from UserDefaults
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decodedFavorites = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            favorites = decodedFavorites
        }
    }
    
    // Save favorites to UserDefaults
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }
    
    // Add a new favorite
    func addFavorite(lineId: String, stationName: String, stationDisplay: String, direction: String) {
        let favorite = FavoriteItem(lineId: lineId, stationName: stationName, stationDisplay: stationDisplay, direction: direction)
        if !favorites.contains(where: { $0.stationName == stationName && $0.lineId == lineId && $0.direction == direction }) {
            favorites.append(favorite)
            saveFavorites()
        }
    }
    
    // Remove a favorite
    func removeFavorite(favorite: FavoriteItem) {
        favorites.removeAll(where: { $0.id == favorite.id })
        saveFavorites()
    }
    
    // Check if a station is already favorited
    func isFavorite(lineId: String, stationName: String, direction: String) -> Bool {
        return favorites.contains(where: { $0.stationName == stationName && $0.lineId == lineId && $0.direction == direction })
    }
}