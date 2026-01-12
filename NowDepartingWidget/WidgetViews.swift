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
                            Text(TerminalStationsHelper.getToTerminalStation(for: favorite.lineId, direction: favorite.direction))
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
                        Text(TerminalStationsHelper.getToTerminalStation(for: favorite.lineId, direction: favorite.direction))
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
    return TimeFormatter.formatArrivalTime(minutes: train.minutes, seconds: train.seconds, fullText: true)
}

func getAdditionalTimeText(for train: (minutes: Int, seconds: Int)) -> String {
    return TimeFormatter.formatAdditionalTime(minutes: train.minutes, seconds: train.seconds)
}

func getSubwayLine(for lineId: String) -> SubwayLine {
    return SubwayLineFactory.line(for: lineId)
}
