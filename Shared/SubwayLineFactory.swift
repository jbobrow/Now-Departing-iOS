//
//  SubwayLineFactory.swift
//  Now Departing
//
//  Factory for creating subway line instances from configuration
//

import SwiftUI

struct SubwayLineFactory {
    /// All NYC subway lines in display order
    static let allLines: [SubwayLine] = {
        let lineIds = ["1", "2", "3", "X", "4", "5", "6", "7",
                       "A", "C", "E", "G", "B", "D", "F", "M",
                       "N", "Q", "R", "W", "J", "Z", "L"]

        return lineIds.map { lineId in
            createLine(id: lineId)
        }
    }()

    /// Create a subway line from configuration
    static func createLine(id: String) -> SubwayLine {
        let colors = SubwayConfiguration.lineColors[id] ?? (background: .gray, foreground: .white)
        return SubwayLine(
            id: id,
            label: id,
            bg_color: colors.background,
            fg_color: colors.foreground
        )
    }

    /// Get a specific line by ID
    static func line(for lineId: String) -> SubwayLine {
        return allLines.first(where: { $0.id == lineId }) ?? createLine(id: lineId)
    }
}

/// Global convenience accessor for backwards compatibility
struct SubwayLinesData {
    static let allLines = SubwayLineFactory.allLines
}
