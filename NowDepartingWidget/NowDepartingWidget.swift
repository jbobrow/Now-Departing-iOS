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
    let nextTrains: [Date]
    let lastUpdated: Date
    let errorMessage: String
}

// MARK: - Timeline Provider

struct TrainTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainEntry {
        let now = Date()
        return TrainEntry(
            date: now,
            favoriteItem: FavoriteItem(
                lineId: "1",
                stationName: "Times Sq-42 St",
                stationDisplay: "Times Sq-42 St",
                direction: "N"
            ),
            nextTrains: [
                now.addingTimeInterval(5 * 60),
                now.addingTimeInterval(12 * 60)
            ],
            lastUpdated: now,
            errorMessage: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainEntry) -> Void) {
        // Get the first favorite or show placeholder
        let favorites = loadFavorites()
        let favorite = favorites.first

        if context.isPreview {
            let now = Date()
            let entry = TrainEntry(
                date: now,
                favoriteItem: favorite ?? FavoriteItem(
                    lineId: "1",
                    stationName: "Times Sq-42 St",
                    stationDisplay: "Times Sq-42 St",
                    direction: "N"
                ),
                nextTrains: [
                    now.addingTimeInterval(5 * 60),
                    now.addingTimeInterval(12 * 60)
                ],
                lastUpdated: now,
                errorMessage: ""
            )
            completion(entry)
        } else if let favorite = favorite {
            fetchTrainTimes(for: favorite) { trains, error, fetchTime in
                let entry = TrainEntry(
                    date: Date(),
                    favoriteItem: favorite,
                    nextTrains: trains,
                    lastUpdated: fetchTime,
                    errorMessage: error
                )
                completion(entry)
            }
        } else {
            completion(TrainEntry(
                date: Date(),
                favoriteItem: nil,
                nextTrains: [],
                lastUpdated: Date(),
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
                lastUpdated: Date(),
                errorMessage: "No favorites set"
            )
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
            completion(timeline)
            return
        }

        fetchTrainTimes(for: favorite) { trains, error, fetchTime in
            let currentDate = Date()
            let entry = TrainEntry(
                date: currentDate,
                favoriteItem: favorite,
                nextTrains: trains,
                lastUpdated: fetchTime,
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

    private func fetchTrainTimes(for favorite: FavoriteItem, completion: @escaping ([Date], String, Date) -> Void) {
        let fetchTime = Date()
        let apiURL = "https://api.wheresthefuckingtrain.com/by-route/\(favorite.lineId)"

        guard let url = URL(string: apiURL) else {
            completion([], "Invalid URL", fetchTime)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                completion([], "Network error", fetchTime)
                return
            }

            guard let data = data else {
                completion([], "No data", fetchTime)
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

                    if arrivalTimes.isEmpty {
                        completion([], "No trains", fetchTime)
                    } else {
                        completion(arrivalTimes, "", fetchTime)
                    }
                } else {
                    completion([], "Station not found", fetchTime)
                }
            } catch {
                completion([], "Error loading data", fetchTime)
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
