//
//  AlertTextRenderer.swift
//  Now Departing
//
//  Parses MTA alert text and renders subway line badges and symbols inline.
//
//  The MTA GTFS-RT alerts feed uses:
//    [A], [1], [G]  → colored circle badge, Helvetica Bold, matching the app's line icons
//    [airplane icon] → white airplane SF symbol
//
//  Badge images are rendered via ImageRenderer (iOS 16+/watchOS 9+) at a fixed internal
//  size and cached; SwiftUI's Text(Image) scales them to match the surrounding font's
//  line height automatically.
//
//  Usage:
//    alertInlineText("No [G] between Bedford-Nostrand Avs and Court Sq", fontSize: 17)
//

import SwiftUI

// MARK: - Public entry point

/// Returns a SwiftUI `Text` with route circle badges and airplane icons rendered inline.
/// Apply font and base foreground color at the call site; badge colors are baked in.
@MainActor
func alertInlineText(_ raw: String, fontSize: CGFloat = 17) -> Text {
    tokenize(raw).reduce(Text("")) { acc, token in
        switch token {
        case .text(let s):
            return acc + Text(s)

        case .airplane:
            return acc + Text(Image(systemName: "airplane"))

        case .route(let id):
            if let img = RouteBadgeCache.shared.badge(for: id) {
                return acc + Text(img)
            } else {
                // Fallback if rendering fails (multi-char like GS, SIR)
                let color = routeBgColor(for: id)
                return acc + Text(id).foregroundColor(color).bold()
            }
        }
    }
}

// MARK: - Badge image cache

@MainActor
private final class RouteBadgeCache {
    static let shared = RouteBadgeCache()
    private var cache: [String: Image] = [:]

    func badge(for routeId: String) -> Image? {
        if let cached = cache[routeId] { return cached }

        let bgColor = routeBgColor(for: routeId)
        let fgColor = routeFgColor(for: routeId)
        // Slightly smaller font for two-char labels (GS, SI) to fit inside the circle
        let internalSize: CGFloat = 48
        let fontRatio: CGFloat = routeId.count == 1 ? 0.65 : 0.52

        let badgeView = ZStack {
            Circle().fill(bgColor)
            Text(routeId)
                .font(.custom("HelveticaNeue-Bold", size: internalSize * fontRatio))
                .foregroundColor(fgColor)
        }
        .frame(width: internalSize, height: internalSize)

        let renderer = ImageRenderer(content: badgeView)
        renderer.scale = 3.0

        // uiImage is available on iOS, tvOS, and watchOS
        guard let uiImage = renderer.uiImage else { return nil }
        let image = Image(uiImage: uiImage)
        cache[routeId] = image
        return image
    }
}

// MARK: - Token

private enum AlertToken {
    case text(String)
    case route(String)
    case airplane
}

// MARK: - Parser

private func tokenize(_ raw: String) -> [AlertToken] {
    var tokens: [AlertToken] = []
    var rest = raw[raw.startIndex...]

    while !rest.isEmpty {
        guard let open = rest.firstIndex(of: "[") else {
            tokens.append(.text(String(rest)))
            break
        }
        if open != rest.startIndex {
            tokens.append(.text(String(rest[..<open])))
        }
        let afterOpen = rest.index(after: open)
        guard let close = rest[afterOpen...].firstIndex(of: "]") else {
            tokens.append(.text(String(rest[open...])))
            break
        }
        let content = String(rest[afterOpen..<close])
        rest = rest[rest.index(after: close)...]

        if content == "airplane icon" {
            tokens.append(.airplane)
        } else {
            tokens.append(.route(content))
        }
    }
    return tokens
}

// MARK: - Color helpers

private func routeBgColor(for routeId: String) -> Color {
    if let c = SubwayConfiguration.lineColors[routeId] { return c.background }
    if routeId.hasSuffix("X") {
        let base = String(routeId.dropLast())
        if let c = SubwayConfiguration.lineColors[base] { return c.background }
    }
    // Gray for unknown/shuttle lines (S, H, GS, SIR, SI, FS, etc.)
    return Color(red: 0.50, green: 0.51, blue: 0.52)
}

private func routeFgColor(for routeId: String) -> Color {
    if let c = SubwayConfiguration.lineColors[routeId] { return c.foreground }
    if routeId.hasSuffix("X") {
        let base = String(routeId.dropLast())
        if let c = SubwayConfiguration.lineColors[base] { return c.foreground }
    }
    return .white
}
