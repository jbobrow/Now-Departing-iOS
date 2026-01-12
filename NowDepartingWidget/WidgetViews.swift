//
//  WidgetViews.swift
//  NowDepartingWidget
//
//  Widget UI views for small, medium, and large widgets
//

import SwiftUI
import WidgetKit

// MARK: - Main Widget Entry View

struct NowDepartingWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TrainEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .systemExtraLarge:
                LargeWidgetView(entry: entry)
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                SmallWidgetView(entry: entry)
            @unknown default:
                SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    var entry: TrainEntry

    var body: some View {
        if let favorite = entry.favoriteItem {
            let line = getSubwayLine(for: favorite.lineId)

            VStack(spacing: 0) {
                // Top row: Line badge
                HStack {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 28))
                        .foregroundColor(line.fg_color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(line.bg_color))

                    Spacer()
                }

                Spacer(minLength: 0)

                // Center: Train time
                VStack(spacing: 2) {
                    if !entry.errorMessage.isEmpty {
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 32))
                            .foregroundColor(.white)
                    } else if !entry.nextTrains.isEmpty {
                        Text(getTimeText(for: entry.nextTrains[0]))
                            .font(.custom("HelveticaNeue-Bold", size: 32))
                            .foregroundColor(.white)

                        if entry.nextTrains.count > 1 {
                            Text(entry.nextTrains.dropFirst().prefix(2).map { train in
                                getAdditionalTimeText(for: train)
                            }.joined(separator: ", "))
                            .font(.custom("HelveticaNeue", size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 2)
                        }
                    } else {
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 32))
                            .foregroundColor(.white)
                    }
                }

                Spacer(minLength: 0)

                // Bottom: Station name
                Text(favorite.stationDisplay)
                    .font(.custom("HelveticaNeue-Bold", size: 11))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                Text("Add a favorite\nin the app")
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    var entry: TrainEntry

    var body: some View {
        if let favorite = entry.favoriteItem {
            let line = getSubwayLine(for: favorite.lineId)

            HStack(spacing: 16) {
                // Left side - Line and station info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(line.label)
                            .font(.custom("HelveticaNeue-Bold", size: 32))
                            .foregroundColor(line.fg_color)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(line.bg_color))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(favorite.stationDisplay)
                                .font(.custom("HelveticaNeue-Bold", size: 16))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Text(WidgetDirectionHelper.getToTerminalStation(for: favorite.lineId, direction: favorite.direction))
                                .font(.custom("HelveticaNeue", size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Right side - Train times
                VStack(spacing: 4) {
                    if !entry.errorMessage.isEmpty {
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    } else if !entry.nextTrains.isEmpty {
                        Text(getTimeText(for: entry.nextTrains[0]))
                            .font(.custom("HelveticaNeue-Bold", size: 28))
                            .foregroundColor(.white)

                        if entry.nextTrains.count > 1 {
                            Text(entry.nextTrains.dropFirst().prefix(2).map { train in
                                getAdditionalTimeText(for: train)
                            }.joined(separator: ", "))
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        }
                    } else {
                        Text("--")
                            .font(.custom("HelveticaNeue-Bold", size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        } else {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                Text("Add a favorite in the app")
                    .font(.custom("HelveticaNeue", size: 16))
                    .foregroundColor(.white)
            }
            .padding()
        }
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    var entry: TrainEntry

    var body: some View {
        if let favorite = entry.favoriteItem {
            let line = getSubwayLine(for: favorite.lineId)

            VStack(spacing: 16) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    Text(line.label)
                        .font(.custom("HelveticaNeue-Bold", size: 50))
                        .foregroundColor(line.fg_color)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(line.bg_color))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(favorite.stationDisplay)
                            .font(.custom("HelveticaNeue-Bold", size: 24))
                            .foregroundColor(.white)
                        Text(WidgetDirectionHelper.getToTerminalStation(for: favorite.lineId, direction: favorite.direction))
                            .font(.custom("HelveticaNeue", size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // Train times
                if !entry.errorMessage.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(entry.errorMessage)
                            .font(.custom("HelveticaNeue", size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if !entry.nextTrains.isEmpty {
                    VStack(spacing: 12) {
                        // Primary time
                        Text(getTimeText(for: entry.nextTrains[0]))
                            .font(.custom("HelveticaNeue-Bold", size: 72))
                            .foregroundColor(.white)

                        // Additional times
                        if entry.nextTrains.count > 1 {
                            Text(entry.nextTrains.dropFirst().prefix(5).map { train in
                                getAdditionalTimeText(for: train)
                            }.joined(separator: ", "))
                            .font(.custom("HelveticaNeue", size: 20))
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    Spacer()
                } else {
                    Spacer()
                    Text("No trains")
                        .font(.custom("HelveticaNeue", size: 18))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
            }
            .padding(24)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                Text("Add a favorite in the app")
                    .font(.custom("HelveticaNeue-Bold", size: 18))
                    .foregroundColor(.white)
                Text("Go to a station and tap 'Add to Favorites'")
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
    }
}

// MARK: - Helper Views

struct DirectionalBackground: View {
    let direction: String
    let lineColor: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                if direction == "N" {
                    // Northbound - curve at top
                    path.move(to: CGPoint(x: 0, y: height * 0.3))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height * 0.3),
                        control: CGPoint(x: width / 2, y: 0)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                } else {
                    // Southbound - curve at bottom
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.7))
                    path.addQuadCurve(
                        to: CGPoint(x: 0, y: height * 0.7),
                        control: CGPoint(x: width / 2, y: height)
                    )
                    path.closeSubpath()
                }
            }
            .fill(lineColor.opacity(0.15))
        }
    }
}

// MARK: - Helper Functions

func getTimeText(for train: (minutes: Int, seconds: Int)) -> String {
    let totalSeconds = train.minutes * 60 + train.seconds

    if totalSeconds == 0 {
        return "Departing"
    } else if totalSeconds <= 30 {
        return "Departing"
    } else if totalSeconds < 60 {
        return "Arriving"
    } else {
        return "\(train.minutes) min"
    }
}

func getAdditionalTimeText(for train: (minutes: Int, seconds: Int)) -> String {
    let totalSeconds = train.minutes * 60 + train.seconds

    if totalSeconds < 60 {
        return "Arriving"
    } else {
        return "\(train.minutes) min"
    }
}

func getSubwayLine(for lineId: String) -> SubwayLine {
    let colors = SubwayConfiguration.lineColors[lineId] ?? (background: .gray, foreground: .white)
    return SubwayLine(id: lineId, label: lineId, bg_color: colors.background, fg_color: colors.foreground)
}

// MARK: - Direction Helper (Widget Version)

struct WidgetDirectionHelper {
    static func getToTerminalStation(for lineId: String, direction: String) -> String {
        // Simplified version for widgets - just show the terminal stations
        let terminals: [String: (N: String, S: String)] = [
            "1": (N: "to Van Cortlandt Park", S: "to South Ferry"),
            "2": (N: "to Wakefield", S: "to Flatbush Av"),
            "3": (N: "to Harlem", S: "to New Lots Av"),
            "4": (N: "to Woodlawn", S: "to New Lots Av/Crown Hts"),
            "5": (N: "to Eastchester", S: "to Flatbush Av"),
            "6": (N: "to Pelham Bay Park", S: "to Brooklyn Bridge"),
            "7": (N: "to Flushing", S: "to Hudson Yards"),
            "A": (N: "to Inwood", S: "to Far Rockaway/Lefferts"),
            "C": (N: "to Washington Heights", S: "to Euclid Av"),
            "E": (N: "to Jamaica Center", S: "to World Trade Center"),
            "G": (N: "to Court Sq", S: "to Church Av"),
            "B": (N: "to Bedford Park", S: "to Brighton Beach"),
            "D": (N: "to Norwood", S: "to Coney Island"),
            "F": (N: "to Jamaica", S: "to Coney Island"),
            "M": (N: "to Forest Hills", S: "to Middle Village"),
            "N": (N: "to Astoria", S: "to Coney Island"),
            "Q": (N: "to 96 St", S: "to Coney Island"),
            "R": (N: "to Forest Hills", S: "to Bay Ridge"),
            "W": (N: "to Astoria", S: "to Whitehall St"),
            "J": (N: "to Jamaica Center", S: "to Broad St"),
            "Z": (N: "to Jamaica Center", S: "to Broad St"),
            "L": (N: "to 8 Av", S: "to Canarsie")
        ]

        if let terminal = terminals[lineId] {
            return direction == "N" ? terminal.N : terminal.S
        }

        return direction == "N" ? "Northbound" : "Southbound"
    }
}
