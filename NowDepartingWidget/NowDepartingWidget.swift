//
//  NowDepartingWidget.swift
//  NowDepartingWidget
//
//  Main widget implementation with configurable timeline provider.
//  Users can select which favorite station appears in each widget instance.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Favorite App Entity

struct FavoriteAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favorite Station")
    static var defaultQuery = FavoriteEntityQuery()

    var id: String
    var lineId: String
    var stationName: String
    var stationDisplay: String
    var direction: String
    var stationGtfsStopId: String?

    var displayRepresentation: DisplayRepresentation {
        let line = SubwayLineFactory.line(for: lineId)
        let terminal = TerminalStationsHelper.getToTerminalStation(for: lineId, direction: direction)
        return DisplayRepresentation(
            title: "\(line.label) \(stationDisplay)",
            subtitle: "\(terminal)"
        )
    }
}

struct FavoriteEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FavoriteAppEntity] {
        let favorites = loadFavorites()
        return identifiers.compactMap { id in
            favorites.first(where: { $0.id == id })?.toAppEntity()
        }
    }

    func suggestedEntities() async throws -> [FavoriteAppEntity] {
        return loadFavorites().map { $0.toAppEntity() }
    }

    func defaultResult() async -> FavoriteAppEntity? {
        return loadFavorites().first?.toAppEntity()
    }

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
}

extension FavoriteItem {
    func toAppEntity() -> FavoriteAppEntity {
        FavoriteAppEntity(
            id: id,
            lineId: lineId,
            stationName: stationName,
            stationDisplay: stationDisplay,
            direction: direction,
            stationGtfsStopId: stationGtfsStopId
        )
    }
}

extension FavoriteAppEntity {
    func toFavoriteItem() -> FavoriteItem {
        FavoriteItem(
            lineId: lineId,
            stationName: stationName,
            stationDisplay: stationDisplay,
            direction: direction,
            stationGtfsStopId: stationGtfsStopId
        )
    }
}

// MARK: - Widget Configuration Intent

struct SelectFavoriteIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Favorite"
    static var description = IntentDescription("Choose which favorite station to display in this widget")

    @Parameter(title: "Station")
    var favorite: FavoriteAppEntity?

    @Parameter(title: "Second Station")
    var secondFavorite: FavoriteAppEntity?

    @Parameter(title: "Third Station (Large Widget)")
    var thirdFavorite: FavoriteAppEntity?

    @Parameter(title: "Fourth Station (Large Widget)")
    var fourthFavorite: FavoriteAppEntity?
}

// MARK: - Widget Entry

struct FavoriteTrainData {
    let favoriteItem: FavoriteItem
    let nextTrains: [Date]
}

struct TrainEntry: TimelineEntry {
    let date: Date
    let favorites: [FavoriteTrainData]
    let lastUpdated: Date
    let errorMessage: String
    let outOfTownDistanceMeters: Double?

    init(date: Date, favorites: [FavoriteTrainData], lastUpdated: Date, errorMessage: String, outOfTownDistanceMeters: Double? = nil) {
        self.date = date
        self.favorites = favorites
        self.lastUpdated = lastUpdated
        self.errorMessage = errorMessage
        self.outOfTownDistanceMeters = outOfTownDistanceMeters
    }
}

// MARK: - Timeline Provider

struct TrainTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TrainEntry {
        let now = Date()
        return TrainEntry(
            date: now,
            favorites: [
                FavoriteTrainData(
                    favoriteItem: FavoriteItem(
                        lineId: "1",
                        stationName: "Times Sq-42 St",
                        stationDisplay: "Times Sq-42 St",
                        direction: "N"
                    ),
                    nextTrains: [
                        now.addingTimeInterval(5 * 60),
                        now.addingTimeInterval(12 * 60)
                    ]
                )
            ],
            lastUpdated: now,
            errorMessage: ""
        )
    }

    func snapshot(for configuration: SelectFavoriteIntent, in context: Context) async -> TrainEntry {
        let favorites = loadFavorites()
        let selectedFavorite = resolveSelectedFavorite(from: configuration, allFavorites: favorites)

        if context.isPreview {
            let now = Date()
            let favorite = selectedFavorite ?? FavoriteItem(
                lineId: "1",
                stationName: "Times Sq-42 St",
                stationDisplay: "Times Sq-42 St",
                direction: "N"
            )
            return TrainEntry(
                date: now,
                favorites: [
                    FavoriteTrainData(
                        favoriteItem: favorite,
                        nextTrains: [
                            now.addingTimeInterval(5 * 60),
                            now.addingTimeInterval(12 * 60)
                        ]
                    )
                ],
                lastUpdated: now,
                errorMessage: ""
            )
        } else if let favorite = selectedFavorite {
            let (trains, error, fetchTime) = await fetchTrainTimesAsync(for: favorite)
            return TrainEntry(
                date: Date(),
                favorites: [FavoriteTrainData(favoriteItem: favorite, nextTrains: trains)],
                lastUpdated: fetchTime,
                errorMessage: error
            )
        } else {
            return TrainEntry(
                date: Date(),
                favorites: [],
                lastUpdated: Date(),
                errorMessage: "No favorites set"
            )
        }
    }

    func timeline(for configuration: SelectFavoriteIntent, in context: Context) async -> Timeline<TrainEntry> {
        let allFavorites = loadFavorites()
        let primaryFavorite = resolveSelectedFavorite(from: configuration, allFavorites: allFavorites)
        let secondFavorite = resolveSecondFavorite(from: configuration, allFavorites: allFavorites)

        // Check if user is out of town — skip MTA fetches and show distance instead
        if let outOfTown = loadOutOfTownData(), outOfTown.distanceMeters * 0.000621371 > 3 {
            let favoritesData: [FavoriteTrainData] = [
                primaryFavorite,
                secondFavorite,
                resolveThirdFavorite(from: configuration, allFavorites: allFavorites),
                resolveFourthFavorite(from: configuration, allFavorites: allFavorites)
            ].compactMap { $0 }.map { FavoriteTrainData(favoriteItem: $0, nextTrains: []) }

            let entry = TrainEntry(
                date: Date(),
                favorites: favoritesData.isEmpty ? allFavorites.prefix(4).map { FavoriteTrainData(favoriteItem: $0, nextTrains: []) } : favoritesData,
                lastUpdated: outOfTown.storedAt,
                errorMessage: "",
                outOfTownDistanceMeters: outOfTown.distanceMeters
            )
            // Refresh every 30 minutes when out of town (no MTA data needed)
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
        }

        guard let primary = primaryFavorite else {
            let entry = TrainEntry(
                date: Date(),
                favorites: [],
                lastUpdated: Date(),
                errorMessage: "No favorites set"
            )
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        }

        // Fetch train times for primary favorite
        let (primaryTrains, primaryError, fetchTime) = await fetchTrainTimesAsync(for: primary)

        // Fetch train times for additional favorites if configured
        var secondData: FavoriteTrainData?
        if let second = secondFavorite {
            let (secondTrains, _, _) = await fetchTrainTimesAsync(for: second)
            secondData = FavoriteTrainData(favoriteItem: second, nextTrains: secondTrains)
        }

        let thirdFavorite = resolveThirdFavorite(from: configuration, allFavorites: allFavorites)
        var thirdData: FavoriteTrainData?
        if let third = thirdFavorite {
            let (thirdTrains, _, _) = await fetchTrainTimesAsync(for: third)
            thirdData = FavoriteTrainData(favoriteItem: third, nextTrains: thirdTrains)
        }

        let fourthFavorite = resolveFourthFavorite(from: configuration, allFavorites: allFavorites)
        var fourthData: FavoriteTrainData?
        if let fourth = fourthFavorite {
            let (fourthTrains, _, _) = await fetchTrainTimesAsync(for: fourth)
            fourthData = FavoriteTrainData(favoriteItem: fourth, nextTrains: fourthTrains)
        }

        let currentDate = Date()
        var entries: [TrainEntry] = []

        // Build favorites array
        func makeFavorites(primaryTrains: [Date]) -> [FavoriteTrainData] {
            var favs = [FavoriteTrainData(favoriteItem: primary, nextTrains: primaryTrains)]
            if let second = secondData { favs.append(second) }
            if let third = thirdData { favs.append(third) }
            if let fourth = fourthData { favs.append(fourth) }
            return favs
        }

        // Initial entry with all upcoming trains
        entries.append(TrainEntry(
            date: currentDate,
            favorites: makeFavorites(primaryTrains: primaryTrains),
            lastUpdated: fetchTime,
            errorMessage: primaryError
        ))

        // Create an entry at each train's departure time with that train removed.
        // This causes WidgetKit to automatically advance to the next train when each
        // one departs, preventing expired trains from showing "X ago" in the widget.
        for (index, trainDate) in primaryTrains.enumerated() {
            guard trainDate > currentDate else { continue }
            let remainingTrains = Array(primaryTrains.dropFirst(index + 1))
            entries.append(TrainEntry(
                date: trainDate,
                favorites: makeFavorites(primaryTrains: remainingTrains),
                lastUpdated: fetchTime,
                errorMessage: primaryError
            ))
        }

        // Create entries at each minute boundary so each pre-rendered snapshot bakes in
        // the correct "X min" value for its scheduled display time (entry.date).
        // Since DynamicTrainTimeView computes relative to entry.date rather than Date(),
        // each snapshot shows the right minute count without needing live re-renders.
        for trainDate in primaryTrains {
            guard trainDate > currentDate else { continue }
            let secondsAway = trainDate.timeIntervalSince(currentDate)
            let minutesAway = min(Int(secondsAway / 60), 90)
            guard minutesAway > 0 else { continue }
            for minute in 1...minutesAway {
                let entryDate = trainDate.addingTimeInterval(-Double(minute) * 60)
                guard entryDate > currentDate else { continue }
                entries.append(TrainEntry(
                    date: entryDate,
                    favorites: makeFavorites(primaryTrains: primaryTrains),
                    lastUpdated: fetchTime,
                    errorMessage: primaryError
                ))
            }
        }

        // WidgetKit requires entries in ascending chronological order.
        entries.sort { $0.date < $1.date }

        // Refresh with fresh MTA data every 5 minutes
        let refreshDate = currentDate.addingTimeInterval(5 * 60)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    // MARK: - Favorite Resolution

    private func resolveSelectedFavorite(from configuration: SelectFavoriteIntent, allFavorites: [FavoriteItem]) -> FavoriteItem? {
        if let selected = configuration.favorite {
            // Try to find the matching favorite in the current list (in case it was updated)
            if let match = allFavorites.first(where: { $0.id == selected.id }) {
                return match
            }
            // Fall back to the entity data
            return selected.toFavoriteItem()
        }
        // Default to first favorite
        return allFavorites.first
    }

    private func resolveSecondFavorite(from configuration: SelectFavoriteIntent, allFavorites: [FavoriteItem]) -> FavoriteItem? {
        guard let selected = configuration.secondFavorite else { return nil }
        if let match = allFavorites.first(where: { $0.id == selected.id }) {
            return match
        }
        return selected.toFavoriteItem()
    }

    private func resolveThirdFavorite(from configuration: SelectFavoriteIntent, allFavorites: [FavoriteItem]) -> FavoriteItem? {
        guard let selected = configuration.thirdFavorite else { return nil }
        if let match = allFavorites.first(where: { $0.id == selected.id }) {
            return match
        }
        return selected.toFavoriteItem()
    }

    private func resolveFourthFavorite(from configuration: SelectFavoriteIntent, allFavorites: [FavoriteItem]) -> FavoriteItem? {
        guard let selected = configuration.fourthFavorite else { return nil }
        if let match = allFavorites.first(where: { $0.id == selected.id }) {
            return match
        }
        return selected.toFavoriteItem()
    }

    // MARK: - Data Loading

    /// Returns stored out-of-town distance and when it was set, or nil if not available / stale.
    private func loadOutOfTownData() -> (distanceMeters: Double, storedAt: Date)? {
        let defaults = UserDefaults(suiteName: "group.com.move38.Now-Departing") ?? UserDefaults.standard
        guard let distMeters = defaults.value(forKey: "outOfTownDistanceMeters") as? Double,
              let rawTimestamp = defaults.value(forKey: "outOfTownTimestamp") as? Double else { return nil }
        let storedAt = Date(timeIntervalSinceReferenceDate: rawTimestamp)
        // Discard if data is more than 4 hours old
        guard Date().timeIntervalSince(storedAt) < 4 * 3600 else { return nil }
        return (distanceMeters: distMeters, storedAt: storedAt)
    }

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

    /// Fetches arrival times for a favorite station via the MTA GTFS-RT feed (async wrapper).
    private func fetchTrainTimesAsync(for favorite: FavoriteItem) async -> (trains: [Date], errorMessage: String, fetchTime: Date) {
        await withCheckedContinuation { continuation in
            let fetchTime = Date()
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
                        continuation.resume(returning: ([], "No trains", fetchTime))
                    } else {
                        continuation.resume(returning: (arrivals, "", fetchTime))
                    }
                case .failure(let error):
                    continuation.resume(returning: ([], error.localizedDescription, fetchTime))
                }
            }
        }
    }
}

// MARK: - Widget Configuration

struct NowDepartingWidget: Widget {
    let kind: String = "NowDepartingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectFavoriteIntent.self, provider: TrainTimelineProvider()) { entry in
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
