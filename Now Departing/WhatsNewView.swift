//
//  WhatsNewView.swift
//  Now Departing
//
//  What a version brings, shown once over the whole app to people who updated
//  to it, and again from the About page. Most updates arrive on their own, so
//  this is the only way they'd hear about them.
//

import SwiftUI

struct WhatsNew: Identifiable {
    struct Item: Identifiable {
        let icon: String
        let title: String
        let detail: String

        var id: String { title }
    }

    /// A picture of the headline feature, above the list.
    enum Art { case linePeek }

    /// Major and minor only, so a 1.8.1 still shows what 1.8 brought.
    let version: String
    var art: Art? = nil
    let items: [Item]

    var id: String { version }

    /// Every version with something to show, newest first. A version without
    /// an entry shows nothing.
    static let releases: [WhatsNew] = [
        WhatsNew(version: "1.8", art: .linePeek, items: [
            Item(icon: "hand.tap", title: "The closest station on any line",
                 detail: "Press and hold a line on the Lines page to see its closest station, the walk there, and the next trains. Tap a direction for all its times."),
            Item(icon: "list.bullet", title: "Closest at the top",
                 detail: "Open a line and the station nearest you leads the list, when it's within walking distance."),
            Item(icon: "figure.walk", title: "Walking times",
                 detail: "Every station on Nearby shows how long it takes to walk there."),
            Item(icon: "hand.draw", title: "Swipe between pages",
                 detail: "Swipe left and right to move between Nearby, Lines and Favorites."),
        ]),
    ]

    static var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// This version's entry, if it has one.
    static var current: WhatsNew? {
        guard let currentVersion else { return nil }
        return releases.first { currentVersion == $0.version || currentVersion.hasPrefix($0.version + ".") }
    }

    /// The newest entry, for the About page.
    static var latest: WhatsNew? { releases.first }
}

/// The version's highlights, in the look of the first-launch walkthrough.
struct WhatsNewView: View {
    let whatsNew: WhatsNew
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    SubwayGlobeArt(height: 110)
                        .accessibilityHidden(true)
                        .padding(.top, 32)

                    Text("What's New")
                        .font(.custom("HelveticaNeue-Bold", size: 34))
                        .padding(.top, 12)
                    Text("in Now Departing \(whatsNew.version)")
                        .font(.custom("HelveticaNeue", size: 18))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    if let art = whatsNew.art {
                        Group {
                            switch art {
                            case .linePeek: LinePeekArt()
                            }
                        }
                        .frame(maxWidth: 340)
                        .accessibilityHidden(true)
                        .padding(.top, 32)
                    }

                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(whatsNew.items) { item in
                            row(item)
                        }
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 420)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnboardingButton(title: "Continue", action: onContinue)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func row(_ item: WhatsNew.Item) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.custom("HelveticaNeue-Bold", size: 18))
                Text(item.detail)
                    .font(.custom("HelveticaNeue", size: 16))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WhatsNewView(whatsNew: WhatsNew.releases[0]) { }
        .preferredColorScheme(.dark)
}
