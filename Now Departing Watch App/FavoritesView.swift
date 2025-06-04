//
//  FavoritesView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/31/25.
//

import SwiftUI
import WatchKit

struct FavoriteWithTimes: Identifiable {
    let id = UUID()
    let favorite: FavoriteItem
    let timesViewModel = TimesViewModel()
    
    var timeText: String {
        guard let nextTrain = timesViewModel.nextTrains.first else { return "—" }
        
        if nextTrain.minutes <= 0 {
            return "Now"
        } else {
            return "\(nextTrain.minutes)m"
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var favoritesWithTimes: [FavoriteWithTimes] = []
    
    let onSelect: (SubwayLine, Station, String) -> Void
    let lines: [SubwayLine]
    
    private func getLine(for id: String) -> SubwayLine? {
        return lines.first(where: { $0.id == id })
    }
    
    private func getDestination(for lineId: String, direction: String) -> String {
        let destinations: [String: (north: String, south: String)] = [
            "1": ("Uptown", "Downtown"),
            "2": ("Uptown", "Brooklyn"),
            "3": ("Uptown", "Brooklyn"),
            "4": ("Uptown", "Brooklyn"),
            "5": ("Uptown", "Brooklyn"),
            "6": ("Uptown", "Downtown"),
            "6X": ("Uptown Express", "Downtown Express"),
            "7": ("Queens", "Manhattan"),
            "7X": ("Queens Express", "Manhattan Express"),
            "A": ("Uptown", "Brooklyn/Queens"),
            "B": ("Uptown", "Brooklyn"),
            "C": ("Uptown", "Brooklyn"),
            "D": ("Uptown", "Brooklyn"),
            "E": ("Queens", "Downtown"),
            "F": ("Queens", "Brooklyn"),
            "G": ("Queens", "Brooklyn"),
            "J": ("Queens", "Manhattan"),
            "L": ("Brooklyn", "Manhattan"),
            "M": ("Queens", "Brooklyn"),
            "N": ("Queens", "Brooklyn"),
            "Q": ("Uptown", "Brooklyn"),
            "R": ("Queens", "Brooklyn"),
            "W": ("Queens", "Manhattan"),
            "Z": ("Queens", "Manhattan")
        ]
        
        let dest = destinations[lineId] ?? (north: "Uptown", south: "Downtown")
        return direction == "N" ? dest.north : dest.south
    }
    
    private func setupFavoritesWithTimes() {
        // Stop existing timers
        favoritesWithTimes.forEach { favoriteWithTimes in
            favoriteWithTimes.timesViewModel.stopFetchingTimes()
        }
        
        // Create new FavoriteWithTimes for current favorites
        favoritesWithTimes = favoritesManager.favorites.map { favorite in
            let favoriteWithTimes = FavoriteWithTimes(favorite: favorite)
            
            // Start fetching times if we can find the line
            if let line = getLine(for: favorite.lineId) {
                let station = Station(display: favorite.stationDisplay, name: favorite.stationName)
                // Set to background mode since this is not the active view
                favoriteWithTimes.timesViewModel.adjustUpdateFrequency(isActive: false)
                favoriteWithTimes.timesViewModel.startFetchingTimes(for: line, station: station, direction: favorite.direction)
            }
            
            return favoriteWithTimes
        }
    }
    
    private func stopAllTimers() {
        favoritesWithTimes.forEach { favoriteWithTimes in
            favoriteWithTimes.timesViewModel.stopFetchingTimes()
        }
    }
    
    var body: some View {
        Group {
            if favoritesManager.favorites.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart")
                        .foregroundColor(.gray)
                        .font(.title2)
                    Text("No Favorites Yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Long press on any departure screen to add it to your favorites")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                List {
                    ForEach(favoritesWithTimes) { favoriteWithTimes in
                        if let line = getLine(for: favoriteWithTimes.favorite.lineId) {
                            Button(action: {
                                // Trigger haptic feedback
                                WKInterfaceDevice.current().play(.start)
                                
                                let station = Station(display: favoriteWithTimes.favorite.stationDisplay, name: favoriteWithTimes.favorite.stationName)
                                onSelect(line, station, favoriteWithTimes.favorite.direction)
                            }) {
                                HStack(spacing: 8) {
                                    // Train line circle - same as NearbyView
                                    Text(line.label)
                                        .font(.custom("HelveticaNeue-Bold", size: 20))
                                        .foregroundColor(line.fg_color)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(line.bg_color))
                                    
                                    // Station and destination info - same layout as NearbyView
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(favoriteWithTimes.favorite.stationDisplay)
                                            .font(.custom("HelveticaNeue-Bold", size: 14))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text("to \(getDestination(for: favoriteWithTimes.favorite.lineId, direction: favoriteWithTimes.favorite.direction))")
                                            .font(.custom("HelveticaNeue", size: 11))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    // Time display - same as NearbyView
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if favoriteWithTimes.timesViewModel.loading && favoriteWithTimes.timesViewModel.nextTrains.isEmpty {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        } else {
                                            Text(favoriteWithTimes.timeText)
                                                .font(.custom("HelveticaNeue-Bold", size: 28))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    favoritesManager.removeFavorite(favorite: favoriteWithTimes.favorite)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    setupFavoritesWithTimes()
                }
            }
        }
        .onAppear {
            setupFavoritesWithTimes()
        }
        .onDisappear {
            stopAllTimers()
        }
        .onChange(of: favoritesManager.favorites) { _, _ in
            setupFavoritesWithTimes()
        }
    }
}
