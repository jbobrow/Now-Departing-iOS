//
//  AlertTextRenderer.swift
//  Now Departing
//
//  Parses MTA alert text and renders subway line badges and symbols inline.
//
//  The MTA GTFS-RT alerts feed uses:
//    [A], [1], [G]       → filled circle badge, Helvetica Bold — matches the app's line icons
//    [6X], [7X]          → filled diamond (45° rotated square) — matches MTA express signage
//    [airplane icon]     → airplane SF symbol
//    [accessibility icon] → ISA-style accessibility icon (blue circle, white figure)
//    [shuttle bus icon]  → grey bus SF symbol
//
//  Text(Image(...)) renders a UIImage at its natural POINT SIZE, not auto-scaled to
//  the font. So badges are rendered at exactly `fontSize` pt via ImageRenderer and
//  cached per (routeId, size). At scale 3.0 this gives crisp @3x pixels.
//
//  Usage:
//    alertInlineText("No [G] between Bedford-Nostrand Avs and Court Sq", fontSize: 17)
//

import SwiftUI

// MARK: - Public entry point

/// Returns a SwiftUI `Text` with route badges and airplane/accessibility icons rendered inline.
/// Pass `fontSize` matching the surrounding font so badges are sized correctly.
/// Apply font and base foreground color at the call site; badge colors are baked in.
@MainActor
func alertInlineText(_ raw: String, fontSize: CGFloat = 17) -> Text {
    tokenize(raw).reduce(Text("")) { acc, token in
        switch token {
        case .text(let s):
            return acc + Text(s)

        case .airplane:
            return acc + Text(Image(systemName: "airplane"))

        case .ada:
            if let img = RouteBadgeCache.shared.adaBadge(size: fontSize) {
                return acc + Text(img)
            } else {
                return acc + Text(Image(systemName: "figure.roll.runningpace.circle.fill"))
                    .foregroundColor(.blue)
            }

        case .shuttleBus:
            if let img = RouteBadgeCache.shared.shuttleBusBadge(size: fontSize) {
                return acc + Text(img)
            } else {
                return acc + Text(Image(systemName: "bus.fill")).foregroundColor(.gray)
            }

        case .route(let id):
            if let img = RouteBadgeCache.shared.badge(for: id, size: fontSize) {
                return acc + Text(img)
            } else {
                // Fallback if rendering fails
                return acc + Text(id).foregroundColor(routeBgColor(for: id)).bold()
            }
        }
    }
}

// MARK: - Badge views

/// Renders a single route badge at the given `size` (in points).
/// Circle for regular routes, 45°-rotated square (diamond) for express variants (6X, 7X).
private struct RouteBadgeView: View {
    let routeId: String
    let bgColor: Color
    let fgColor: Color
    let size: CGFloat

    private var isExpress: Bool { routeId.count == 2 && routeId.hasSuffix("X") }
    private var displayLabel: String { isExpress ? String(routeId.dropLast()) : routeId }

    private var fontRatio: CGFloat {
        if isExpress          { return 0.52 }  // slightly smaller to clear diamond corners
        if routeId.count == 1 { return 0.65 }
        return 0.52  // two-char non-express (GS, SI, etc.)
    }

    var body: some View {
        ZStack {
            if isExpress {
                // Side = size/√2 × 0.96 ≈ size × 0.679 so corners reach ~96% of the frame
                let side = size * 0.679
                Rectangle()
                    .fill(bgColor)
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(45))
            } else {
                Circle().fill(bgColor)
            }
            Text(displayLabel)
                .font(.custom("HelveticaNeue-Bold", size: size * fontRatio))
                .foregroundColor(fgColor)
        }
        .frame(width: size, height: size)
    }
}

/// Renders the ISA-style accessibility icon: white circle backing + blue filled symbol.
/// Matches the standard international "wheelchair accessible" visual.
private struct ADABadgeView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // White backing so the blue circle reads as a solid shape on any background
            Image(systemName: "circle.fill")
                .font(.system(size: size))
                .foregroundColor(.white)
            Image(systemName: "figure.roll.runningpace.circle.fill")
                .font(.system(size: size))
                .foregroundColor(.blue)
        }
        .frame(width: size, height: size)
    }
}

/// Renders a grey bus icon for shuttle bus service.
private struct ShuttleBusIconView: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "bus.fill")
            .font(.system(size: size * 0.9))
            .foregroundColor(Color(red: 0.50, green: 0.51, blue: 0.52))
            .frame(width: size, height: size)
    }
}

// MARK: - Badge image cache

@MainActor
private final class RouteBadgeCache {
    static let shared = RouteBadgeCache()
    private var cache: [String: Image] = [:]

    /// Returns a UIImage-backed SwiftUI Image with point dimensions `size × size`.
    /// Text(Image(...)) renders at those point dimensions, so pass the surrounding fontSize.
    func badge(for routeId: String, size: CGFloat) -> Image? {
        let key = "\(routeId)@\(Int(size * 10))"
        if let cached = cache[key] { return cached }

        let view = RouteBadgeView(
            routeId: routeId,
            bgColor: routeBgColor(for: routeId),
            fgColor: routeFgColor(for: routeId),
            size: size
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0   // @3x quality; UIImage.size = size × size points

        guard let uiImage = renderer.uiImage else { return nil }
        let image = Image(uiImage: uiImage)
        cache[key] = image
        return image
    }

    func adaBadge(size: CGFloat) -> Image? {
        let key = "ada@\(Int(size * 10))"
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(content: ADABadgeView(size: size))
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage else { return nil }
        let image = Image(uiImage: uiImage)
        cache[key] = image
        return image
    }

    func shuttleBusBadge(size: CGFloat) -> Image? {
        let key = "shuttlebus@\(Int(size * 10))"
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(content: ShuttleBusIconView(size: size))
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage else { return nil }
        let image = Image(uiImage: uiImage)
        cache[key] = image
        return image
    }
}

// MARK: - Token

private enum AlertToken {
    case text(String)
    case route(String)
    case airplane
    case ada
    case shuttleBus
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

        switch content.lowercased() {
        case "airplane icon":
            tokens.append(.airplane)
        case "accessibility icon", "accessible icon", "ada icon", "ada", "wheelchair icon", "wheelchair":
            tokens.append(.ada)
        case "shuttle bus icon", "shuttle bus":
            tokens.append(.shuttleBus)
        default:
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
    return Color(red: 0.50, green: 0.51, blue: 0.52)  // gray for unknowns (S, H, GS, SIR…)
}

private func routeFgColor(for routeId: String) -> Color {
    if let c = SubwayConfiguration.lineColors[routeId] { return c.foreground }
    if routeId.hasSuffix("X") {
        let base = String(routeId.dropLast())
        if let c = SubwayConfiguration.lineColors[base] { return c.foreground }
    }
    return .white
}
