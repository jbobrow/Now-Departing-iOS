//
//  FavoritesView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/31/25.
//


import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    let onSelect: (SubwayLine, Station, String) -> Void
    let lines: [SubwayLine]
    
    private func getLine(for id: String) -> SubwayLine? {
        return lines.first(where: { $0.id == id })
    }
    
    var body: some View {
        Group {
            if favoritesManager.favorites.isEmpty {
                VStack(spacing: 8) {
                    Text("No Favorites Yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Long press on any departure screen to add it to your favorites")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List {
                    ForEach(favoritesManager.favorites) { favorite in
                        if let line = getLine(for: favorite.lineId) {
                            Button(action: {
                                let station = Station(display: favorite.stationDisplay, name: favorite.stationName)
                                onSelect(line, station, favorite.direction)
                            }) {
                                HStack {
                                    Text(line.label)
                                        .font(.custom("HelveticaNeue-Bold", size: 20))
                                        .foregroundColor(line.fg_color)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(line.bg_color))
                                    
                                    Text(favorite.stationDisplay)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    favoritesManager.removeFavorite(favorite: favorite)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
