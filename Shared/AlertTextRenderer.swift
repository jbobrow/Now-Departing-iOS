//
//  AlertTextRenderer.swift
//  Now Departing
//
//  Parses MTA alert text and renders subway line badges and symbols inline.
//
//  The MTA GTFS-RT alerts feed uses:
//    [A], [1], [G]   → filled circle badge, Helvetica Bold — matches the app's line icons
//    [6X], [7X]      → filled diamond (45° rotated square) — matches MTA express signage
//    [airplane icon] → airplane SF symbol
//
//  Badges are rendered via ImageRenderer (iOS 16+/watchOS 9+) at a fixed internal
//  size and cached by route ID. SwiftUI's Text(Image) scales them to the surrounding
//  font's line height automatically.
//
//  Usage:
//    alertInlineText("No [G] between Bedford-Nostrand Avs and Court Sq", fontSize: 17)
//

import SwiftUI

// MARK: - Public entry point

/// Returns a SwiftUI `Text` with route badges and airplane icons rendered inline.
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
                // Fallback if rendering fails
                return acc + Text(id).foregroundColor(routeBgColor(for: id)).bold()
            }
        }
    }
}

// MARK: - Badge view

/// Renders a single route badge: circle for regular routes, diamond for express (xX).
private struct RouteBadgeView: View {
    let routeId: String
    let bgColor: Color
    let fgColor: Color

    /// Express routes (6X, 7X) use a diamond; everything else uses a circle.
    private var isExpress: Bool { routeId.count == 2 && routeId.hasSuffix("X") }
    /// Show just the base number inside the diamond (MTA convention: "6" not "6X").
    private var displayLabel: String { isExpress ? String(routeId.dropLast()) : routeId }

    private static let size: CGFloat = 48
    private var fontRatio: CGFloat {
        if isExpress    { return 0.52 }  // slightly smaller to clear diamond corners
        if routeId.count == 1 { return 0.65 }
        return 0.52  // two-char non-express (GS, SI, etc.)
    }

    var body: some View {
        ZStack {
            if isExpress {
                // Diamond: a square rotated 45°, sized so its corners reach ~96% of the frame.
                // Side = size / √2  ×  0.96  ≈  size × 0.679
                let side = Self.size * 0.679
                Rectangle()
                    .fill(bgColor)
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(45))
            } else {
                Circle().fill(bgColor)
            }
            Text(displayLabel)
                .font(.custom("HelveticaNeue-Bold", size: Self.size * fontRatio))
                .foregroundColor(fgColor)
        }
        .frame(width: Self.size, height: Self.size)
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

        let view = RouteBadgeView(routeId: routeId, bgColor: bgColor, fgColor: fgColor)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

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
