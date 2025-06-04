//
//  FavoritesView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/31/25.
//

import SwiftUI
import WatchKit
import Combine

class FavoriteWithTimes: ObservableObject, Identifiable {
    let id = UUID()
    let favorite: FavoriteItem
    let timesViewModel = TimesViewModel()
    @Published var isWaitingToStart = true
    private var cancellables = Set<AnyCancellable>()
    
    var timeText: String {
        guard let nextTrain = timesViewModel.nextTrains.first else { return "—" }
        
        if nextTrain.minutes <= 0 {
            return "Now"
        } else {
            return "\(nextTrain.minutes)m"
        }
    }

    var shouldShowLoader: Bool {
        let result = (timesViewModel.loading || isWaitingToStart) && timesViewModel.nextTrains.isEmpty
        print("DEBUG shouldShowLoader for \(favorite.stationDisplay): loading=\(timesViewModel.loading), waiting=\(isWaitingToStart), nextTrains.count=\(timesViewModel.nextTrains.count), result=\(result)")
        return result
    }
    
    init(favorite: FavoriteItem) {
        self.favorite = favorite
        print("DEBUG: Created FavoriteWithTimes for \(favorite.stationDisplay)")
        
        // Forward changes from timesViewModel to this object
        timesViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

struct FavoriteRowView: View {
    @ObservedObject var favoriteWithTimes: FavoriteWithTimes
    let line: SubwayLine?
    let onSelect: (SubwayLine, Station, String) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        if let line = line {
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
                        
                        Text(DirectionHelper.getToDestination(for: favoriteWithTimes.favorite.lineId, direction: favoriteWithTimes.favorite.direction))
                            .font(.custom("HelveticaNeue", size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Time display - same as NearbyView
                    VStack(alignment: .trailing, spacing: 2) {
                        if favoriteWithTimes.shouldShowLoader {
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                        else if !favoriteWithTimes.timesViewModel.errorMessage.isEmpty && favoriteWithTimes.timesViewModel.nextTrains.isEmpty {
                            Text("--")
                                .font(.custom("HelveticaNeue-Bold", size: 20))
                                .foregroundColor(.gray)
                        }
                        else {
                            Text(favoriteWithTimes.timeText)
                                .font(.custom("HelveticaNeue-Bold", size: 20))
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
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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
    
    private func setupFavoritesWithTimes() {
        print("DEBUG: Setting up favorites with times, count: \(favoritesManager.favorites.count)")
        
        // Stop existing timers
        favoritesWithTimes.forEach { favoriteWithTimes in
            favoriteWithTimes.timesViewModel.stopFetchingTimes()
        }
        
        // Create new FavoriteWithTimes for current favorites
        favoritesWithTimes = favoritesManager.favorites.enumerated().map { index, favorite in
            let favoriteWithTimes = FavoriteWithTimes(favorite: favorite)
            
            // Start fetching times if we can find the line
            if let line = getLine(for: favorite.lineId) {
                let station = Station(display: favorite.stationDisplay, name: favorite.stationName)
                // Set to background mode since this is not the active view
                favoriteWithTimes.timesViewModel.adjustUpdateFrequency(isActive: false)
                
                // Add a small delay to stagger the API requests
                let delay = Double(index) * 0.5 // space the requests half a second apart
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    print("DEBUG: About to set isWaitingToStart = false for \(favorite.stationDisplay)")
                    favoriteWithTimes.isWaitingToStart = false
                    print("DEBUG: isWaitingToStart is now \(favoriteWithTimes.isWaitingToStart) for \(favorite.stationDisplay)")
                    favoriteWithTimes.timesViewModel.startFetchingTimes(for: line, station: station, direction: favorite.direction)
                }
                
                print("DEBUG: Setting up favorite for \(favorite.stationDisplay) \(favorite.lineId) \(favorite.direction) with delay \(delay)")
            }
            
            return favoriteWithTimes
        }
        
        print("DEBUG: Created \(favoritesWithTimes.count) favorites with times")
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
                        FavoriteRowView(
                            favoriteWithTimes: favoriteWithTimes,
                            line: getLine(for: favoriteWithTimes.favorite.lineId),
                            onSelect: onSelect,
                            onDelete: { favoritesManager.removeFavorite(favorite: favoriteWithTimes.favorite) }
                        )
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    setupFavoritesWithTimes()
                }
            }
        }
        .onAppear {
            if favoritesWithTimes.isEmpty {
                setupFavoritesWithTimes()
            }
        }
        .onDisappear {
            stopAllTimers()
        }
        .onChange(of: favoritesManager.favorites) { _, _ in
            setupFavoritesWithTimes()
        }
    }
}
