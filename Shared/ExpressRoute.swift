//
//  ExpressRoute.swift
//  Now Departing
//
//  The MTA runs "diamond" express variants of a few lines — 6X, 7X and FX in the
//  GTFS feeds — that skip local stops during rush hour. Riders think of these as
//  the 6, 7 and F, so the app treats them as trips of the base line and marks each
//  express trip with a small diamond in the line's color, matching MTA signage.
//

import Foundation
import SwiftUI

enum ExpressRoute {
    /// True for diamond-express route IDs ("6X", "7X", "FX").
    static func isExpress(_ routeId: String) -> Bool {
        routeId.count == 2 && routeId.hasSuffix("X")
    }

    /// The line a route ID belongs to: "6X" → "6", "A" → "A".
    static func baseLine(for routeId: String) -> String {
        isExpress(routeId) ? String(routeId.dropLast()) : routeId
    }

    /// Whether a feed trip with `routeId` should be shown for `lineId`.
    static func route(_ routeId: String, servesLine lineId: String) -> Bool {
        baseLine(for: routeId) == baseLine(for: lineId)
    }
}

/// A single upcoming train at a stop.
struct MTAArrival: Codable, Equatable {
    let time: Date
    /// Feed route ID, e.g. "6" or "6X".
    let routeId: String

    var isExpress: Bool { ExpressRoute.isExpress(routeId) }
}

// MARK: - Diamond mark

enum ExpressMark {
    /// A filled diamond sized and vertically centered for text set at `fontSize`.
    /// Read by VoiceOver as "Express".
    static func diamond(color: Color, fontSize: CGFloat) -> Text {
        // Half the font size reads well in list text; grow more slowly beyond that
        // so it stays a marker, not a second headline, next to large times.
        let glyphSize = min(fontSize * 0.5, fontSize * 0.25 + 6).rounded()
        // Center the glyph on the cap height (≈0.71em for Helvetica Neue) rather
        // than sitting it on the baseline.
        let offset = ((fontSize * 0.71 - glyphSize * 0.86) / 2).rounded()
        return Text(Image(systemName: "diamond.fill"))
            .font(.system(size: glyphSize, weight: .bold))
            .foregroundColor(color)
            .baselineOffset(offset)
            .accessibilityLabel("Express")
    }

    /// `text`, preceded by a diamond when the train is express.
    static func label(_ text: String, isExpress: Bool, color: Color, fontSize: CGFloat) -> Text {
        guard isExpress else { return Text(text) }
        return diamond(color: color, fontSize: fontSize) + Text("\u{202F}" + text)  // narrow no-break space keeps the diamond with its time
    }

    /// A comma-separated list of times, each express one preceded by a diamond.
    static func list(_ items: [(text: String, isExpress: Bool)], color: Color, fontSize: CGFloat) -> Text {
        items.enumerated().reduce(Text("")) { result, item in
            let piece = label(item.element.text, isExpress: item.element.isExpress, color: color, fontSize: fontSize)
            return item.offset == 0 ? piece : result + Text(", ") + piece
        }
    }
}
