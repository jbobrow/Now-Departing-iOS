//
//  ServiceAlertBadge.swift
//  Now Departing
//
//  The warning sign on a line's bullet when its service has changed.
//

import SwiftUI
import UIKit

/// The yellow warning sign on a line's bullet when its service has changed,
/// outlined in the background's color so it stands off the bullet. Drawn once per size and kept,
/// since the outline takes many passes and lists redraw every second. Used by
/// the iPhone and watch apps.
struct ServiceAlertBadge: View {
    var size: CGFloat = 14
    var outline: CGFloat = 2
    /// The color behind the bullet, so the sign looks cut out of it.
    var outlineColor: Color = .black

    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme   // yellow is a shade lighter in dark mode

    private static var rendered: [String: UIImage] = [:]

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
            } else {
                OutlinedAlertSign(size: size, outline: outline, outlineColor: outlineColor)
            }
        }
        .padding(-outline)   // lays out at the sign's own size
        .accessibilityLabel("Service change")
    }

    private var image: UIImage? {
        let key = "\(size)/\(outline)/\(outlineColor)/\(displayScale)/\(colorScheme)"
        if let image = Self.rendered[key] { return image }
        // Drawn outside the view tree, so it needs the appearance passed in
        let renderer = ImageRenderer(content: OutlinedAlertSign(size: size, outline: outline, outlineColor: outlineColor)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = displayScale
        let image = renderer.uiImage
        Self.rendered[key] = image
        return image
    }
}

/// The sign with an even outline, traced around a circle so its corners
/// stay concentric with the sign's. Padded by the outline's width.
private struct OutlinedAlertSign: View {
    let size: CGFloat
    let outline: CGFloat
    let outlineColor: Color

    private static let steps = 48

    var body: some View {
        let sign = Image(systemName: "exclamationmark.triangle.fill").font(.system(size: size))
        sign
            .foregroundStyle(.yellow)
            .padding(outline)
            .background {
                outlineColor.mask { outlineShape(sign) }
            }
    }

    private func outlineShape(_ sign: some View) -> some View {
        // Each pixel keeps the most any copy covers it ("lighten"), rather than
        // stacking their soft edges, which would harden the outline's edge
        ZStack {
            ForEach(0..<Self.steps, id: \.self) { step in
                let angle = Double(step) / Double(Self.steps) * 2 * .pi
                sign.offset(x: outline * cos(angle), y: outline * sin(angle))
                    .blendMode(.lighten)
            }
            sign.blendMode(.lighten)   // fills the exclamation mark's cutout
        }
        .foregroundStyle(.white)
        .padding(outline)
        .background(.black)
        .compositingGroup()
        .luminanceToAlpha()   // white coverage becomes the outline's opacity
    }
}
