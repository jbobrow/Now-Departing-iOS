//
//  OnboardingView.swift
//  Now Departing
//
//  First-launch walkthrough: the stations around you (asking for location in
//  context), the closest station on any line, and favorites everywhere. Also
//  opened from "How it works" on the About page.
//

import SwiftUI
import CoreLocation

enum Onboarding {
    static let completedKey = "hasCompletedOnboarding"

    /// Decides once, on the first launch with the walkthrough, whether this
    /// install needs it. Anyone who used the app before it existed skips it
    /// and sees What's New instead.
    static func skipForEarlierInstalls() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: completedKey) == nil else { return }
        let usedBefore = ["cachedStations", "savedFavorites", "hasUserEnabledLocation_iOS", "lastViewedStation"]
            .contains { defaults.object(forKey: $0) != nil }
            || CLLocationManager().authorizationStatus != .notDetermined
        defaults.set(usedBefore, forKey: completedKey)
    }
}

extension LocationManager {
    /// Asks for location and remembers the choice, so later launches find
    /// nearby stations right away.
    func enableForNearby() {
        requestLocationPermission()
        startLocationUpdates()
        hasUserEnabledLocation = true
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @EnvironmentObject var locationManager: LocationManager
    @State private var page = 0
    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("Skip") {
                        withAnimation { page = pageCount - 1 }
                    }
                    .font(.custom("HelveticaNeue-Medium", size: 17))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 20)
                }
            }
            .frame(height: 44)

            TabView(selection: $page) {
                OnboardingPage(
                    title: "Now Departing",
                    message: "Know when your train is coming.\nThat's it."
                ) { SubwayGlobeArt(height: 300) }
                    .tag(0)
                OnboardingPage(
                    title: "Trains near you",
                    message: "Live countdowns for every train nearby, and how long the walk is to each station."
                ) {
                    NearbyArt()
                } footer: {
                    LocationRow()
                }
                    .tag(1)
                OnboardingPage(
                    title: "The closest station on any line",
                    message: "Tap a line on the Lines page for all its stations. Press and hold for the one closest to you and its next trains."
                ) { LinePeekArt(isPlaying: page == 2) }
                    .tag(2)
                OnboardingPage(
                    title: "Know at a glance",
                    message: "Swipe right on a train to make it a favorite, then add a widget to your Home\u{00A0}Screen to see when it's coming."
                ) { FavoriteArt() }
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: i == page ? 20 : 7, height: 7)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .accessibilityHidden(true)
            .padding(.bottom, 20)

            OnboardingButton(title: page < pageCount - 1 ? "Continue" : "Get started") {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// The wide blue button at the bottom of the walkthrough and What's New.
struct OnboardingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("HelveticaNeue-Bold", size: 18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.blue, in: Capsule())
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}

/// Illustration on top, then a title, a short explanation, and anything to do
/// about it. Scrolls when it doesn't fit, as on a small phone at a large text size.
private struct OnboardingPage<Art: View, Footer: View>: View {
    let title: String
    let message: String
    @ViewBuilder let art: Art
    @ViewBuilder let footer: Footer

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    art
                        .frame(maxWidth: 340)
                        .accessibilityHidden(true)
                    Spacer(minLength: 28)
                    Text(title)
                        .font(.custom("HelveticaNeue-Bold", size: 32))
                        .multilineTextAlignment(.center)
                    Text(message.noWidow)
                        .font(.custom("HelveticaNeue", size: 18))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 340)
                        .padding(.top, 12)
                    footer
                        .frame(maxWidth: 420)
                        .padding(.top, 24)
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

extension OnboardingPage where Footer == EmptyView {
    init(title: String, message: String, @ViewBuilder art: () -> Art) {
        self.init(title: title, message: message, art: art, footer: { EmptyView() })
    }
}

// MARK: - Location

/// Asks for location on the page about nearby stations, then shows that it's on.
private struct LocationRow: View {
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "location.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.blue, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Location")
                    .font(.custom("HelveticaNeue-Bold", size: 17))
                Text("Only used to find stations near you, never collected.".noWidow)
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            switch locationManager.authorizationStatus {
            case .notDetermined:
                Button("Allow") { locationManager.enableForNearby() }
                    .font(.custom("HelveticaNeue-Bold", size: 16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .background(Color.blue, in: Capsule())
            case .authorizedWhenInUse, .authorizedAlways:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Allowed")
            default:
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.custom("HelveticaNeue-Bold", size: 16))
                .foregroundStyle(.blue)
                .frame(minHeight: 36)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Illustrations

/// The green-topped globe lamp that marks a subway entrance open all night, as
/// on the website, glowing, with its post fading into the dark below.
struct SubwayGlobeArt: View {
    var height: CGFloat

    // The drawing is 550 × 1050, globe centered at (275, 245)
    private static let aspect: CGFloat = 550 / 1050
    private static let globeCenter: CGFloat = 245 / 1050

    var body: some View {
        // The post runs past the frame's bottom, so the globe sits higher
        let imageHeight = height * 1.15
        let glowY = imageHeight * Self.globeCenter
        ZStack(alignment: .top) {
            RadialGradient(colors: [Color(red: 1, green: 0.88, blue: 0.44).opacity(0.32), .clear],
                           center: .center, startRadius: 0, endRadius: imageHeight * 0.42)
                .frame(width: imageHeight * 0.84, height: imageHeight * 0.84)
                .offset(y: glowY - imageHeight * 0.42)
            Image("SubwayGlobe")
                .resizable()
                .frame(width: imageHeight * Self.aspect, height: imageHeight)
                .frame(height: height, alignment: .top)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        // The glow spills past the top, unclipped
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
    }
}

/// Union Square on the Nearby page.
private struct NearbyArt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NearbyView.StationHeader(stationDisplay: "Union Square", distanceText: "180ft",
                                     detailText: WalkTime.format(60))
            ArtTrainRow(line: "4", destination: "Uptown & Bronx", terminal: "to Woodlawn", minutes: [1, 6, 11])
            ArtTrainRow(line: "L", destination: "Manhattan", terminal: "to 8th Avenue", minutes: [3, 7, 12])
            ArtTrainRow(line: "Q", destination: "Uptown", terminal: "to 96th Street", minutes: [7, 15])
        }
        .padding(18)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Holding the 6 on the Lines page: a finger presses it, the rest of the grid
/// fades, and its closest station opens out of it with times both ways. Plays
/// on a loop while `isPlaying`; otherwise, or with Reduce Motion, rests on the peek.
struct LinePeekArt: View {
    var isPlaying = true

    private enum Phase { case idle, pressing, peeking }

    @State private var phase = Phase.peeking
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let held = "6"

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ForEach(["4", "5", "6", "7"], id: \.self) { id in
                    LineBullet(line: id, size: 60)
                        .scaleEffect(scale(for: id))
                        .grayscale(id != held && phase == .peeking ? 1 : 0)
                        .opacity(id != held && phase == .peeking ? 0.25 : 1)
                        .overlay {
                            if id == held { finger }
                        }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                NearbyView.StationHeader(stationDisplay: "Union Square", distanceText: "180ft",
                                         detailText: WalkTime.format(60))
                ArtTrainRow(line: held, destination: "Uptown & Bronx", terminal: "to Pelham Bay Park", minutes: [2, 5, 9])
                ArtTrainRow(line: held, destination: "Downtown", terminal: "to Brooklyn Bridge-City Hall", minutes: [5, 8, 14])
            }
            .padding(18)
            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            // Grows out of the held bullet, which sits right of center
            .scaleEffect(phase == .peeking ? 1 : 0.4, anchor: UnitPoint(x: 0.6, y: 0))
            .opacity(phase == .peeking ? 1 : 0)
        }
        .task(id: isPlaying && !reduceMotion) {
            guard isPlaying && !reduceMotion else {
                phase = .peeking
                return
            }
            await loop()
        }
    }

    private func scale(for id: String) -> CGFloat {
        guard id == held else { return 1 }
        switch phase {
        case .idle: return 1
        case .pressing: return 0.9
        case .peeking: return 1.08
        }
    }

    /// A fingertip resting on the bullet while it's pressed.
    private var finger: some View {
        Circle()
            .fill(.white.opacity(0.35))
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
            .frame(width: 40, height: 40)
            .offset(x: 6, y: 10)
            .opacity(phase == .pressing ? 1 : 0)
            .scaleEffect(phase == .pressing ? 1 : 1.4)
    }

    private func loop() async {
        withAnimation(.easeOut(duration: 0.3)) { phase = .idle }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 0.25)) { phase = .pressing }
            try? await Task.sleep(for: .seconds(0.55))   // about as long as the real press
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { phase = .peeking }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { phase = .idle }
        }
    }
}

/// A train on Nearby swiped right to show its Favorite button, and the same
/// train in a widget.
private struct FavoriteArt: View {
    private let buttonWidth: CGFloat = 84

    var body: some View {
        VStack(spacing: 18) {
            ArtTrainRow(line: "6", destination: "Uptown & Bronx", terminal: "to Pelham Bay Park", minutes: [2, 5, 9])
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: 340)
                .background(Color(white: 0.11))
                .offset(x: buttonWidth)
                .background(alignment: .leading) {
                    VStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                        Text("Favorite")
                            .font(.custom("HelveticaNeue-Medium", size: 13))
                    }
                    .foregroundStyle(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.blue)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            WidgetArt()
        }
    }
}

/// The small Home Screen widget for that train, laid out like the real one.
private struct WidgetArt: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                LineBullet(line: "6", size: 44)
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text("2 min")
                    .font(.custom("HelveticaNeue-Bold", size: 32))
                Text("5m, 9m")
                    .font(.custom("HelveticaNeue", size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text("Union Square")
                    .font(.custom("HelveticaNeue-Bold", size: 13))
                Text("to Pelham Bay Park")
                    .font(.custom("HelveticaNeue", size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
        }
        .padding(16)
        .frame(width: 158, height: 158)
        .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct LineBullet: View {
    let line: String
    let size: CGFloat

    var body: some View {
        let colors = SubwayConfiguration.lineColors[line]
        Text(line)
            .font(.custom("HelveticaNeue-Bold", size: size * 0.67))
            .foregroundColor(colors?.foreground ?? .white)
            .frame(width: size, height: size)
            .background(Circle().fill(colors?.background ?? .gray))
    }
}

/// A train in one direction, with the metrics of the Nearby page's rows.
private struct ArtTrainRow: View {
    let line: String
    let destination: String
    let terminal: String
    let minutes: [Int]

    var body: some View {
        HStack(spacing: 12) {
            LineBullet(line: line, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(destination)
                    .font(.custom("HelveticaNeue-Bold", size: 20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(terminal)
                    .font(.custom("HelveticaNeue", size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let first = minutes.first {
                    Text("\(first) min")
                        .font(.custom("HelveticaNeue-Bold", size: 26))
                        .fixedSize()
                }
                if minutes.count > 1 {
                    Text(minutes.dropFirst().map { "\($0)m" }.joined(separator: ", "))
                        .font(.custom("HelveticaNeue", size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
        }
    }
}

extension String {
    /// Joins the last two words with a non-breaking space so a line never ends
    /// with a single word on its own.
    var noWidow: String {
        guard let space = range(of: " ", options: .backwards) else { return self }
        return replacingCharacters(in: space, with: "\u{00A0}")
    }
}

#Preview {
    OnboardingView { }
        .environmentObject(LocationManager())
        .preferredColorScheme(.dark)
}
