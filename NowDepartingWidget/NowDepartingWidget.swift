//
//  NowDepartingWidget.swift
//  NowDepartingWidget
//
//  Main widget implementation with timeline provider.
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
        let favorites = loadFavorites()
        let favorite = favorites.first

        if context.isPreview {
            let now = Date()
            completion(TrainEntry(
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
            ))
        } else if let favorite = favorite {
            fetchTrainTimes(for: favorite) { trains, error, fetchTime in
                completion(TrainEntry(
                    date: Date(),
                    favoriteItem: favorite,
                    nextTrains: trains,
                    lastUpdated: fetchTime,
                    errorMessage: error
                ))
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
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))))
            return
        }

        fetchTrainTimes(for: favorite) { trains, error, fetchTime in
            let currentDate = Date()
            var entries: [TrainEntry] = []

            entries.append(TrainEntry(date: currentDate, favoriteItem: favorite, nextTrains: trains, lastUpdated: fetchTime, errorMessage: error))

            if let date30 = Calendar.current.date(byAdding: .second, value: 30, to: currentDate) {
                entries.append(TrainEntry(date: date30, favoriteItem: favorite, nextTrains: trains, lastUpdated: fetchTime, errorMessage: error))
            }

            if let date60 = Calendar.current.date(byAdding: .second, value: 60, to: currentDate) {
                entries.append(TrainEntry(date: date60, favoriteItem: favorite, nextTrains: trains, lastUpdated: fetchTime, errorMessage: error))
            }

            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    // MARK: - Data Loading

    private func loadFavorites() -> [FavoriteItem] {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.move38.Now-Departing"),
           let data = sharedDefaults.data(forKey: "savedFavorites"),
           let favorites = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            return favorites
        }
        if let data = UserDefaults.standard.data(forKey: "savedFavorites"),
           let favorites = try? JSONDecoder().decode([FavoriteItem].self, from: data) {
            return favorites
        }
        return []
    }

    /// Fetches arrival times for a favorite station via the MTA GTFS-RT feed.
    ///
    /// The `FavoriteItem` must have been saved with a valid `stationGtfsStopId`.
    /// If the stop ID is missing, the widget falls back to an empty result with
    /// an explanatory error string.
    private func fetchTrainTimes(
        for favorite: FavoriteItem,
        completion: @escaping (_ trains: [Date], _ errorMessage: String, _ fetchTime: Date) -> Void
    ) {
        let fetchTime = Date()

        // Build a Station from the FavoriteItem so we can call MTAFeedService.
        let station = Station(
            display: favorite.stationDisplay,
            name: favorite.stationName,
            gtfsStopId: favorite.stationGtfsStopId
        )

        MTAFeedService.shared.fetchArrivals(
            routeId: favorite.lineId,
            station: station,
            direction: favorite.direction
        ) { result in
            switch result {
            case .success(let arrivals):
                if arrivals.isEmpty {
                    completion([], "No trains", fetchTime)
                } else {
                    completion(arrivals, "", fetchTime)
                }
            case .failure(let error):
                completion([], error.localizedDescription, fetchTime)
            }
        }
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
