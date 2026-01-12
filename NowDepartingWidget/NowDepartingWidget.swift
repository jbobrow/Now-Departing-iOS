//
//  NowDepartingWidget.swift
//  NowDepartingWidget
//
//  Main widget implementation with timeline provider
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct TrainEntry: TimelineEntry {
    let date: Date
    let favoriteItem: FavoriteItem?
    let nextTrains: [(minutes: Int, seconds: Int)]
    let errorMessage: String
}

// MARK: - Timeline Provider

struct TrainTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainEntry {
        TrainEntry(
            date: Date(),
            favoriteItem: FavoriteItem(
                lineId: "1",
                stationName: "Times Sq-42 St",
                stationDisplay: "Times Sq-42 St",
                direction: "N"
            ),
            nextTrains: [(minutes: 5, seconds: 0), (minutes: 12, seconds: 0)],
            errorMessage: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainEntry) -> Void) {
        // Get the first favorite or show placeholder
        let favorites = loadFavorites()
        let favorite = favorites.first

        if context.isPreview {
            let entry = TrainEntry(
                date: Date(),
                favoriteItem: favorite ?? FavoriteItem(
                    lineId: "1",
                    stationName: "Times Sq-42 St",
                    stationDisplay: "Times Sq-42 St",
                    direction: "N"
                ),
                nextTrains: [(minutes: 5, seconds: 0), (minutes: 12, seconds: 0)],
                errorMessage: ""
            )
            completion(entry)
        } else if let favorite = favorite {
            fetchTrainTimes(for: favorite) { trains, error in
                let entry = TrainEntry(
                    date: Date(),
                    favoriteItem: favorite,
                    nextTrains: trains,
                    errorMessage: error
                )
                completion(entry)
            }
        } else {
            completion(TrainEntry(
                date: Date(),
                favoriteItem: nil,
                nextTrains: [],
                errorMessage: "No favorites set"
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainEntry>) -> Void) {
        let favorites = loadFavorites()

        guard let favorite = favorites.first else {
            let entry = TrainEntry(
                date: Date(),
                favoriteItem: nil,
                nextTrains: [],
                errorMessage: "No favorites set"
            )
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
            completion(timeline)
            return
        }

        fetchTrainTimes(for: favorite) { trains, error in
            let currentDate = Date()
            let entry = TrainEntry(
                date: currentDate,
                favoriteItem: favorite,
                nextTrains: trains,
                errorMessage: error
            )

            // Refresh every 30 seconds
            let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    // MARK: - Data Loading

    private func loadFavorites() -> [FavoriteItem] {
        // Use App Group to share data between app and widget
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.move38.Now-Departing"),
              let data = sharedDefaults.data(forKey: "savedFavorites"),
              let favorites = try? JSONDecoder().decode([FavoriteItem].self, from: data) else {
            // Fallback to standard UserDefaults for testing
            if let data = UserDefaults.standard.data(forKey: "savedFavorites"),
               let favorites = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
                return favorites
            }
            return []
        }
        return favorites
    }

    private func fetchTrainTimes(for favorite: FavoriteItem, completion: @escaping ([(minutes: Int, seconds: Int)], String) -> Void) {
        let apiURL = "https://api.wheresthefuckingtrain.com/by-route/\(favorite.lineId)"

        guard let url = URL(string: apiURL) else {
            completion([], "Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                completion([], "Network error")
                return
            }

            guard let data = data else {
                completion([], "No data")
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                if let stationData = apiResponse.data.first(where: { $0.name == favorite.stationName }) {
                    let trains = favorite.direction == "N" ? stationData.N : stationData.S
                    let filteredTrains = trains.filter { $0.route == favorite.lineId }

                    let formatter = ISO8601DateFormatter()
                    let now = Date()
                    let arrivalTimes = filteredTrains.compactMap { train -> Date? in
                        formatter.date(from: train.time)
                    }.filter { $0 > now }
                    .sorted()

                    let nextTrains = arrivalTimes.compactMap { arrivalTime -> (minutes: Int, seconds: Int)? in
                        let interval = arrivalTime.timeIntervalSince(now)
                        if interval < 0 { return nil }

                        let totalSeconds = Int(interval)
                        let minutes = totalSeconds / 60
                        let seconds = totalSeconds % 60

                        return (minutes: minutes, seconds: seconds)
                    }.sorted { $0.minutes * 60 + $0.seconds < $1.minutes * 60 + $1.seconds }

                    if nextTrains.isEmpty {
                        completion([], "No trains")
                    } else {
                        completion(nextTrains, "")
                    }
                } else {
                    completion([], "Station not found")
                }
            } catch {
                completion([], "Error loading data")
            }
        }.resume()
    }
}

// MARK: - Widget Configuration

struct NowDepartingWidget: Widget {
    let kind: String = "NowDepartingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainTimelineProvider()) { entry in
            NowDepartingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Now Departing")
        .description("See train times for your favorite station")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct NowDepartingWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowDepartingWidget()
        NowDepartingWidgetLiveActivity()
    }
}
