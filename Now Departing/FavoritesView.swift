//
//  FavoritesView.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 7/24/25.
//


import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationDataManager: StationDataManager
    @StateObject private var trainDataManager = FavoriteTrainDataManager()
    @State private var showingEditMode = false
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if favoritesManager.favorites.isEmpty {
                EmptyFavoritesView()
            } else {
                FavoritesList()
            }
        }
        .onAppear {
            refreshTrainData()
        }
        .refreshable {
            await refreshTrainDataAsync()
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    // MARK: - Favorites List
    
    @ViewBuilder
    private func FavoritesList() -> some View {
        List {
            Section {
                ForEach(favoritesManager.favorites) { favorite in
                    FavoriteTrainRow(
                        favorite: favorite,
                        trainData: trainDataManager.getTrainData(for: favorite),
                        isLoaded: trainDataManager.isLoaded(for: favorite),
                        stationDataManager: stationDataManager
                    )
                }
                .onDelete(perform: deleteFavorites)
                .onMove(perform: moveFavorites)
            } header: {
                HStack {
                    Text("Favorites")
                        .font(.custom("HelveticaNeue-Bold", size: 32))
                        .foregroundColor(.primary)
                        .textCase(.none)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    Spacer()
                    if let note = trainDataManager.offlineNote(for: favoritesManager.favorites, currentTime: currentTime) {
                        Text(note)
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.secondary)
                            .textCase(.none)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .background(Color.black)
        .listStyle(.plain)
        .clipped() // Prevent content from showing above the header
        .padding(.top, 64)
        .ignoresSafeArea(edges: .top)
    }

    
    // MARK: - Actions
    
    private func deleteFavorites(offsets: IndexSet) {
        for index in offsets {
            let favorite = favoritesManager.favorites[index]
            favoritesManager.removeFavorite(favorite: favorite)
        }
    }
    
    private func moveFavorites(from source: IndexSet, to destination: Int) {
        favoritesManager.reorderFavorites(from: source, to: destination)
    }
    
    private func refreshTrainData() {
        for favorite in favoritesManager.favorites {
            trainDataManager.fetchTrainData(for: favorite)
        }
    }
    
    @MainActor
    private func refreshTrainDataAsync() async {
        for favorite in favoritesManager.favorites {
            await trainDataManager.fetchTrainDataAsync(for: favorite)
        }
    }
}

// MARK: - Empty State View

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 16) {
                Text("No Favorites Yet")
                    .font(.custom("HelveticaNeue-Bold", size: 32))
                    .multilineTextAlignment(.center)
                
                Text("Swipe right on any train in the Nearby tab to add it to your favorites")
                    .font(.custom("HelveticaNeue", size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            
            Spacer()
                        
            Spacer()
                .frame(height: 64)
        }
        .padding()
    }
}


// MARK: - Favorite Train Row

struct FavoriteTrainRow: View {
    let favorite: FavoriteItem
    let trainData: [TrainArrival]?
    let isLoaded: Bool
    let stationDataManager: StationDataManager
    @EnvironmentObject var serviceAlertsManager: ServiceAlertsManager
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var line: SubwayLine? {
        SubwayLinesData.allLines.first(where: { $0.id == favorite.lineId })
    }
    
    var body: some View {
        Group {
            if let line = line {
                NavigationLink(value: NavigationRoute.times(
                    line,
                    stationDataManager.findStation(lineId: favorite.lineId, name: favorite.stationName, gtfsStopId: favorite.stationGtfsStopId)
                        ?? Station(display: favorite.stationDisplay, name: favorite.stationName, gtfsStopId: favorite.stationGtfsStopId),
                    favorite.direction
                )) {
                    rowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                rowContent
            }
        }
        .onReceive(timer) { time in
            currentTime = time
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 12) {
                // Station and Line Info
                HStack(alignment: .top, spacing: 12) {
                    // Line badge with optional alert indicator
                    if let line = line {
                        ZStack(alignment: .topTrailing) {
                            Text(line.label)
                                .font(.custom("HelveticaNeue-Bold", size: 32))
                                .foregroundColor(line.fg_color)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(line.bg_color))
                            if serviceAlertsManager.hasActiveAlerts(for: favorite.lineId) {
                                ServiceAlertBadge()
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.stationDisplay)
                        .font(.custom("HelveticaNeue-Bold", size: 20))
                        .lineLimit(2)
                    
                    Text(DirectionHelper.getToTerminalStation(
                        for: favorite.lineId,
                        direction: favorite.direction,
                        stationDataManager: stationDataManager
                    ))
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Train Times with Loading State
                VStack(alignment: .trailing, spacing: 2) {
                    if let trainData = trainData, !trainData.isEmpty {
                        // Primary time
                        ExpressMark.label(getTimeText(for: trainData.first!), isExpress: trainData.first!.isExpress, color: expressColor, fontSize: 26)
                            .font(.custom("HelveticaNeue-Bold", size: 26))
                            .foregroundColor(.primary)
                        
                        // Additional times (if any)
                        if trainData.count > 1 {
                            HStack {
                                ExpressMark.list(trainData.dropFirst().prefix(5).map { train in
                                    (text: getAdditionalTimeText(for: train), isExpress: train.isExpress)
                                }, color: expressColor, fontSize: 14)
                                .font(.custom("HelveticaNeue", size: 14))
                                .foregroundColor(.secondary)
                            }
                        }
                    } else if isLoaded {
                        // Fetch completed but no upcoming trains
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 26))
                            .foregroundColor(.primary)

                        Text("No trains")
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        // First fetch still in progress
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var expressColor: Color {
        line?.bg_color ?? .secondary
    }

    // Helper functions for time formatting
    private func getTimeText(for train: TrainArrival) -> String {
        return TimeFormatter.formatArrivalTime(train.arrivalTime, currentTime: currentTime, fullText: true)
    }

    private func getAdditionalTimeText(for train: TrainArrival) -> String {
        return TimeFormatter.formatArrivalTime(train.arrivalTime, currentTime: currentTime)
    }
}

// MARK: - Train Times View

struct TrainTimesView: View {
    let trainData: [TrainArrival]
    let currentTime: Date
    
    var body: some View {
        HStack {
            ForEach(trainData.prefix(3), id: \.arrivalTime) { train in
                Text(getTimeText(for: train))
                    .font(.custom("HelveticaNeue-Bold", size: 16))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            
            if trainData.count > 3 {
                Text("+\(trainData.count - 3)")
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func getTimeText(for train: TrainArrival) -> String {
        return TimeFormatter.formatArrivalTime(train.arrivalTime, currentTime: currentTime, fullText: true)
    }
}

// MARK: - Train Data Manager for Favorites

class FavoriteTrainDataManager: ObservableObject {
    @Published private var trainDataCache: [String: [TrainArrival]] = [:]
    @Published private var updatedAt: [String: Date] = [:]
    /// Favorites whose last refresh failed, so their times are from an earlier one.
    @Published private var offlineKeys: Set<String> = []
    @Published private var attemptedKeys: Set<String> = []
    private var lastFetchTime: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 30 // 30 seconds

    private func cacheKey(for favorite: FavoriteItem) -> String {
        "\(favorite.lineId)-\(favorite.stationName)-\(favorite.direction)"
    }

    func getTrainData(for favorite: FavoriteItem) -> [TrainArrival]? {
        guard let data = trainDataCache[cacheKey(for: favorite)] else { return nil }
        let now = Date()
        let fresh = data.filter { $0.arrivalTime.timeIntervalSince(now) > -60 }
        return fresh.isEmpty ? nil : fresh
    }

    /// True once a fetch has finished, whether or not it got through.
    func isLoaded(for favorite: FavoriteItem) -> Bool {
        attemptedKeys.contains(cacheKey(for: favorite))
    }

    /// Note for the list when any favorite is showing times kept from an earlier
    /// fetch; nil while everything is current.
    func offlineNote(for favorites: [FavoriteItem], currentTime: Date = Date()) -> String? {
        let keys = favorites.map(cacheKey(for:)).filter { offlineKeys.contains($0) }
        guard !keys.isEmpty else { return nil }
        return TimeFormatter.offlineNote(lastUpdated: keys.compactMap { updatedAt[$0] }.min(), currentTime: currentTime)
    }

    func fetchTrainData(for favorite: FavoriteItem) {
        let key = cacheKey(for: favorite)

        // Check if we need to fetch (cache timeout)
        if let lastFetch = lastFetchTime[key],
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return
        }

        fetchTrainDataFromAPI(for: favorite, key: key, completion: {})
    }

    @MainActor
    func fetchTrainDataAsync(for favorite: FavoriteItem) async {
        await withCheckedContinuation { continuation in
            fetchTrainDataFromAPI(for: favorite, key: cacheKey(for: favorite)) {
                continuation.resume()
            }
        }
    }

    private func fetchTrainDataFromAPI(for favorite: FavoriteItem, key: String, completion: @escaping () -> Void) {
        // Show the last times seen for this favorite until the fetch lands, or for
        // as long as there's no service to fetch with.
        if trainDataCache[key] == nil,
           let snapshot = ArrivalSnapshotStore.load(routeId: favorite.lineId, stopId: favorite.stationGtfsStopId, direction: favorite.direction) {
            trainDataCache[key] = snapshot.arrivals.map { TrainArrival(arrivalTime: $0.time, routeId: $0.routeId) }
            updatedAt[key] = snapshot.fetchedAt
        }

        let station = Station(
            display: favorite.stationDisplay,
            name: favorite.stationName,
            gtfsStopId: favorite.stationGtfsStopId
        )

        MTAFeedService.shared.fetchTrainArrivals(
            routeId: favorite.lineId,
            station: station,
            direction: favorite.direction
        ) { [weak self] result in
            guard let self = self else { completion(); return }
            switch result {
            case .success(let arrivals):
                let trainArrivals = arrivals.map { TrainArrival(arrivalTime: $0.time, routeId: $0.routeId) }
                print("DEBUG: Processed \(trainArrivals.count) trains for favorite: \(favorite.stationDisplay) \(favorite.lineId) \(favorite.direction)")
                self.trainDataCache[key] = trainArrivals
                self.lastFetchTime[key] = Date()
                self.updatedAt[key] = Date()
                self.offlineKeys.remove(key)
            case .failure:
                // Keep whatever times we have; they still count down correctly.
                self.offlineKeys.insert(key)
            }
            self.attemptedKeys.insert(key)
            completion()
        }
    }
}

// MARK: - Supporting Data Structures

struct TrainArrival: Equatable {
    let arrivalTime: Date
    let routeId: String

    var isExpress: Bool { ExpressRoute.isExpress(routeId) }
}
