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
    
    var body: some View {
        NavigationView {
            Group {
                if favoritesManager.favorites.isEmpty {
                    EmptyFavoritesView()
                } else {
                    FavoritesList()
                }
            }
        }
        .onAppear {
            refreshTrainData()
        }
        .refreshable {
            await refreshTrainDataAsync()
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
        // Note: You'll need to add a reorder function to FavoritesManager
        // For now, this is a placeholder
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
                    station: Station(display: favorite.stationDisplay, name: favorite.stationName),
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
                    // Line badge
                    if let line = line {
                        Text(line.label)
                            .font(.custom("HelveticaNeue-Bold", size: 32))
                            .foregroundColor(line.fg_color)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(line.bg_color))
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
                .onChange(of: trainData) { oldData, newData in  // ← NEW: Reset timeout when data arrives
                    // Reset timeout when new data arrives
                    if newData != nil && !newData!.isEmpty {
                        hasTimedOut = false
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Helper functions for time formatting
    private func getTimeText(for train: TrainArrival) -> String {
        let interval = train.arrivalTime.timeIntervalSince(currentTime)
        let minutes = max(0, Int(interval / 60))
        
        if minutes == 0 {
            return "Now"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) min"
        }
    }

    private func getAdditionalTimeText(for train: TrainArrival) -> String {
        let interval = train.arrivalTime.timeIntervalSince(currentTime)
        let minutes = max(0, Int(interval / 60))
        
        if minutes == 0 {
            return "Now"
        } else {
            return "\(minutes)m"
        }
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
        let interval = train.arrivalTime.timeIntervalSince(currentTime)
        let minutes = max(0, Int(interval / 60))
        
        if minutes == 0 {
            return "Now"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - Train Data Manager for Favorites

class FavoriteTrainDataManager: ObservableObject {
    @Published private var trainDataCache: [String: [TrainArrival]] = [:]
    private var lastFetchTime: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 30 // 30 seconds
    
    func getTrainData(for favorite: FavoriteItem) -> [TrainArrival]? {
        let key = "\(favorite.lineId)-\(favorite.stationName)-\(favorite.direction)"
        return trainDataCache[key]
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
        guard let url = URL(string: "https://api.wheresthefuckingtrain.com/by-route/\(favorite.lineId)") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(APIResponse.self, from: data) else {
                return
            }
            
            DispatchQueue.main.async {
                self?.processAPIResponse(response, for: favorite, key: key)
            }
        }.resume()
    }
    
    @MainActor
    private func fetchTrainDataFromAPIAsync(for favorite: FavoriteItem, key: String) async {
        guard let url = URL(string: "https://api.wheresthefuckingtrain.com/by-route/\(favorite.lineId)") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(APIResponse.self, from: data)
            processAPIResponse(response, for: favorite, key: key)
        } catch {
            print("Error fetching train data: \(error)")
        }
    }
    
    private func processAPIResponse(_ response: APIResponse, for favorite: FavoriteItem, key: String) {
        guard let stationData = response.data.first(where: { $0.name == favorite.stationName }) else {
            return
        }
        
        let trains = favorite.direction == "N" ? stationData.N : stationData.S
        let filteredTrains = trains.filter { $0.route == favorite.lineId }
        
        let trainArrivals = filteredTrains.compactMap { train -> TrainArrival? in
            // Convert time string to Date using ISO8601DateFormatter
            let formatter = ISO8601DateFormatter()
            guard let arrivalTime = formatter.date(from: train.time) else {
                print("DEBUG: Failed to parse time: \(train.time)")
                return nil
            }
            return TrainArrival(arrivalTime: arrivalTime, routeId: train.route)
        }.filter { $0.arrivalTime > Date() } // Only keep future times
        .sorted { $0.arrivalTime < $1.arrivalTime }
        
        print("DEBUG: Processed \(trainArrivals.count) trains for favorite: \(favorite.stationDisplay) \(favorite.lineId) \(favorite.direction)")
        
        trainDataCache[key] = trainArrivals
        lastFetchTime[key] = Date()
    }
}

// MARK: - Supporting Data Structures

struct TrainArrival: Equatable {
    let arrivalTime: Date
    let routeId: String
}
