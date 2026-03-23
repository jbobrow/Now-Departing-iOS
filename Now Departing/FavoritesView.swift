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
    @ObservedObject var deepLinkManager: DeepLinkManager
    @State private var showingEditMode = false
    @State private var navigationPath = NavigationPath()
    @State private var deepLinkTimesView: (line: SubwayLine, station: Station, direction: String)? = nil

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
        .onChange(of: deepLinkManager.activeLink) { oldLink, newLink in
            if let link = newLink {
                handleDeepLink(link)
                deepLinkManager.clearLink()
            }
        }
        .fullScreenCover(item: Binding(
            get: { deepLinkTimesView.map { DeepLinkWrapper(line: $0.line, station: $0.station, direction: $0.direction) } },
            set: { if $0 == nil { deepLinkTimesView = nil } }
        )) { wrapper in
            NavigationStack {
                TimesView(line: wrapper.line, station: wrapper.station, direction: wrapper.direction)
                    .environmentObject(favoritesManager)
                    .environmentObject(stationDataManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                deepLinkTimesView = nil
                            }
                        }
                    }
            }
        }
    }

    // Wrapper to make the deep link data Identifiable
    private struct DeepLinkWrapper: Identifiable {
        let id = UUID()
        let line: SubwayLine
        let station: Station
        let direction: String
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

    private func handleDeepLink(_ link: DeepLinkManager.DeepLink) {
        // Find the line
        let line = SubwayLineFactory.line(for: link.lineId)

        // Look up the full station (with gtfsStopId) from station data, falling back to a minimal Station
        let station = stationDataManager.findStation(byName: link.stationName)
            ?? Station(display: link.stationDisplay, name: link.stationName)

        // Show the times view
        deepLinkTimesView = (line: line, station: station, direction: link.direction)
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
                
                Text("Swipe left or right on any train in the Nearby tab to add it to your favorites")
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
    let stationDataManager: StationDataManager
    @EnvironmentObject var serviceAlertsManager: ServiceAlertsManager
    @State private var currentTime = Date()
    @State private var hasTimedOut = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var line: SubwayLine? {
        SubwayLinesData.allLines.first(where: { $0.id == favorite.lineId })
    }
    
    var body: some View {
        Group {
            if let line = line {
                NavigationLink(destination: TimesView(
                    line: line,
                    station: stationDataManager.findStation(byName: favorite.stationName)
                        ?? Station(display: favorite.stationDisplay, name: favorite.stationName, gtfsStopId: favorite.stationGtfsStopId),
                    direction: favorite.direction
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
                                ZStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.black)
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yellow)
                                }
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
                        Text(getTimeText(for: trainData.first!))
                            .font(.custom("HelveticaNeue-Bold", size: 26))
                            .foregroundColor(.primary)
                        
                        // Additional times (if any)
                        if trainData.count > 1 {
                            HStack {
                                Text(trainData.dropFirst().prefix(5).map { train in
                                    getAdditionalTimeText(for: train)
                                }.joined(separator: ", "))
                                .font(.custom("HelveticaNeue", size: 14))
                                .foregroundColor(.secondary)
                            }
                        }
                    } else if hasTimedOut {  // ← NEW: Show "--" after timeout
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 26))
                            .foregroundColor(.primary)

                        Text("No trains")
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        // Loading state
                        VStack(alignment: .center) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Spacer()
                        }
                    }
                }
                .onAppear {  // ← NEW: Added timeout logic
                    // Set timeout for loading state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        if trainData?.isEmpty ?? true {
                            hasTimedOut = true
                        }
                    }
                }
                .onChange(of: trainData) { oldData, newData in
                    if newData != nil && !newData!.isEmpty {
                        hasTimedOut = false
                    } else {
                        // Data became empty (trains expired or fetch failed) — restart timeout
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            if trainData?.isEmpty ?? true {
                                hasTimedOut = true
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
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
    private var lastFetchTime: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 30 // 30 seconds
    
    func getTrainData(for favorite: FavoriteItem) -> [TrainArrival]? {
        let key = "\(favorite.lineId)-\(favorite.stationName)-\(favorite.direction)"
        guard let data = trainDataCache[key] else { return nil }
        let now = Date()
        let fresh = data.filter { $0.arrivalTime.timeIntervalSince(now) > -60 }
        return fresh.isEmpty ? nil : fresh
    }
    
    func fetchTrainData(for favorite: FavoriteItem) {
        let key = "\(favorite.lineId)-\(favorite.stationName)-\(favorite.direction)"
        
        // Check if we need to fetch (cache timeout)
        if let lastFetch = lastFetchTime[key],
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return
        }
        
        // Fetch train data
        fetchTrainDataFromAPI(for: favorite, key: key)
    }
    
    @MainActor
    func fetchTrainDataAsync(for favorite: FavoriteItem) async {
        let key = "\(favorite.lineId)-\(favorite.stationName)-\(favorite.direction)"
        await fetchTrainDataFromAPIAsync(for: favorite, key: key)
    }
    
    private func fetchTrainDataFromAPI(for favorite: FavoriteItem, key: String) {
        let station = Station(
            display: favorite.stationDisplay,
            name: favorite.stationName,
            gtfsStopId: favorite.stationGtfsStopId
        )

        MTAFeedService.shared.fetchArrivals(
            routeId: favorite.lineId,
            station: station,
            direction: favorite.direction
        ) { [weak self] result in
            guard let self = self else { return }
            if case .success(let arrivals) = result {
                let trainArrivals = arrivals.map { TrainArrival(arrivalTime: $0, routeId: favorite.lineId) }
                print("DEBUG: Processed \(trainArrivals.count) trains for favorite: \(favorite.stationDisplay) \(favorite.lineId) \(favorite.direction)")
                self.trainDataCache[key] = trainArrivals
                self.lastFetchTime[key] = Date()
            }
        }
    }

    @MainActor
    private func fetchTrainDataFromAPIAsync(for favorite: FavoriteItem, key: String) async {
        let station = Station(
            display: favorite.stationDisplay,
            name: favorite.stationName,
            gtfsStopId: favorite.stationGtfsStopId
        )

        await withCheckedContinuation { continuation in
            MTAFeedService.shared.fetchArrivals(
                routeId: favorite.lineId,
                station: station,
                direction: favorite.direction
            ) { [weak self] result in
                guard let self = self else { continuation.resume(); return }
                if case .success(let arrivals) = result {
                    let trainArrivals = arrivals.map { TrainArrival(arrivalTime: $0, routeId: favorite.lineId) }
                    self.trainDataCache[key] = trainArrivals
                    self.lastFetchTime[key] = Date()
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Supporting Data Structures

struct TrainArrival: Equatable {
    let arrivalTime: Date
    let routeId: String
}
