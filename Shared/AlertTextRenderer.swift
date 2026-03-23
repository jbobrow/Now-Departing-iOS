//
//  AlertTextRenderer.swift
//  Now Departing
//
//  Parses MTA alert text and renders subway line badges and symbols inline.
//
//  The MTA GTFS-RT alerts feed uses:
//    [A], [1], [G]  → colored circle icons for each subway route
//    [airplane icon] → white airplane SF symbol
//
//  Usage:
//    alertInlineText("No [G] between Bedford-Nostrand Avs and Court Sq")
//    // Returns a Text with a green G-circle replacing [G]
//

import SwiftUI

// MARK: - Public entry point

/// Parses MTA alert text and returns a SwiftUI `Text` with route circles and
/// airplane icons substituted in place. Font and base foreground color should
/// be applied at the call site; per-token colors (route badges) are preserved.
func alertInlineText(_ raw: String) -> Text {
    tokenize(raw).reduce(Text("")) { acc, token in
        switch token {
        case .text(let s):
            return acc + Text(s)

        case .airplane:
            return acc + Text(Image(systemName: "airplane"))

        case .route(let id):
            let color = routeColor(for: id)
            if let symbol = circleSymbol(for: id) {
                // Single-char route: use an SF Symbol filled circle (e.g. "g.circle.fill")
                return acc + Text(Image(systemName: symbol)).foregroundColor(color)
            } else {
                // Multi-char route (GS, SIR, 6X…): bold colored text, no circle available
                return acc + Text(id).foregroundColor(color).bold()
            }
        }
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
            // No matching ']' — treat the rest as plain text
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

// MARK: - Helpers

/// Returns the SF Symbol name for a single-character route ID, or nil for multi-char IDs.
/// Example: "G" → "g.circle.fill", "1" → "1.circle.fill", "GS" → nil
private func circleSymbol(for routeId: String) -> String? {
    guard routeId.count == 1, let char = routeId.first,
          char.isLetter || char.isNumber else { return nil }
    return "\(char.lowercased()).circle.fill"
}

/// Returns the MTA brand background color for a given route ID.
/// Falls back to stripping a trailing "X" (express variants like 6X, 7X),
/// then to gray for unknown/shuttle lines (S, H, GS, SI, SIR, etc.).
/// Single-char unknowns like S and H still render as a gray circle.
private func routeColor(for routeId: String) -> Color {
    if let c = SubwayConfiguration.lineColors[routeId] { return c.background }
    // Express variants share their base line's color (e.g. 6X → 6)
    if routeId.hasSuffix("X") {
        let base = String(routeId.dropLast())
        if let c = SubwayConfiguration.lineColors[base] { return c.background }
    }
    // Gray for unknown/shuttle lines (S, H, GS, SIR, SI, FS, etc.)
    return Color(red: 0.50, green: 0.51, blue: 0.52)
}
