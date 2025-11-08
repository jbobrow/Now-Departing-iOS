//
//  ContentView.swift (iOS)
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/8/25.
//

import SwiftUI

// MARK: - Main Content View with Standard TabView (Automatic Liquid Glass)

struct ContentView_iOS: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Nearby Tab
            NearbyView(onLocationRequested: {
                locationManager.requestOneTimeUpdate()
            })
            .tabItem {
                Label("Nearby", systemImage: "location.fill")
            }
            .tag(0)
            
            // Favorites Tab
            FavoritesViewiOS()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(1)
        }
        .tint(.white)
    }
}

// MARK: - Favorites View

struct FavoritesViewiOS: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationDataManager: StationDataManager
    
    var body: some View {
        NavigationStack {
            Group {
                if favoritesManager.favorites.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Favorites Yet")
                            .font(.custom("HelveticaNeue-Bold", size: 24))
                            .foregroundColor(.white)
                        
                        Text("Swipe on any train in the Nearby tab to add it to your favorites")
                            .font(.custom("HelveticaNeue", size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                } else {
                    List {
                        ForEach(favoritesManager.favorites) { favorite in
                            FavoriteRowViewiOS(favorite: favorite)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                favoritesManager.removeFavorite(favorite: favoritesManager.favorites[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct FavoriteRowViewiOS: View {
    let favorite: FavoriteItem
    @EnvironmentObject var stationDataManager: StationDataManager
    
    private var line: SubwayLine? {
        SubwayLinesData.allLines.first(where: { $0.id == favorite.lineId })
    }
    
    var body: some View {
        if let line = line {
            HStack(spacing: 12) {
                // Line badge
                Text(line.label)
                    .font(.custom("HelveticaNeue-Bold", size: 24))
                    .foregroundColor(line.fg_color)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(line.bg_color))
                
                // Station info
                VStack(alignment: .leading, spacing: 4) {
                    Text(favorite.stationDisplay)
                        .font(.custom("HelveticaNeue-Bold", size: 18))
                        .foregroundColor(.white)
                    
                    Text(DirectionHelper.getToDestination(for: favorite.lineId, direction: favorite.direction))
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}
