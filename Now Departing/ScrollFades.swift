//
//  ScrollFades.swift
//  Now Departing
//
//  Fades that let rows leave a list smoothly instead of stopping at a hard edge
//  or reappearing when a pinned header gives way to the next.
//

import SwiftUI

extension View {
    /// Fades the top `height` points of a scrolling list into black. Keep it
    /// within the gap above the pinned header's first line, so nothing at rest
    /// is dimmed.
    func topScrollFade(height: CGFloat = 12) -> some View {
        overlay(alignment: .top) {
            // Eased rather than linear, so the fade has no visible lower edge
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.7), location: 0.3),
                    .init(color: .black.opacity(0.3), location: 0.6),
                    .init(color: .black.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }

    /// Fades a list row out as it slides up under its section's pinned header,
    /// gone by the time the header covers it. The system fades a pinned header
    /// out as the next one arrives; without this, the end of its section shows
    /// through the gap until the new header reaches the top.
    ///
    /// `headerBottom` is the pinned header's bottom edge on screen. Rows measure
    /// themselves globally because the list's own scroll space isn't reachable
    /// from inside it.
    func fadesUnderHeader(bottom headerBottom: CGFloat, over distance: CGFloat = 32) -> some View {
        visualEffect { content, proxy in
            let visibleBelowHeader = proxy.frame(in: .global).maxY - headerBottom
            return content.opacity(min(max(visibleBelowHeader / distance, 0), 1))
        }
    }
}
