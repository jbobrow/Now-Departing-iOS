//
//  WelcomeCarouselView.swift
//  Now Departing
//
//  Created on 2026-01-13.
//

import SwiftUI

struct WelcomeCarouselView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [CarouselPage] = [
        CarouselPage(
            icon: "train.side.front.car",
            title: "Welcome to Now Departing",
            description: "Your fastest way to find NYC subway trains in real-time",
            accentColor: .blue
        ),
        CarouselPage(
            icon: "location.fill",
            title: "Nearby Trains",
            description: "See trains arriving at stations near you with live departure times",
            accentColor: .green
        ),
        CarouselPage(
            icon: "star.fill",
            title: "Save Your Favorites",
            description: "Swipe left or right on any train to quickly add it to your favorites",
            accentColor: .yellow
        ),
        CarouselPage(
            icon: "square.grid.2x2.fill",
            title: "Widgets & Live Activities",
            description: "Add widgets to your home screen and track trains in StandBy mode",
            accentColor: .purple
        ),
        CarouselPage(
            icon: "checkmark.circle.fill",
            title: "You're All Set!",
            description: "Let's find your train and get you on your way",
            accentColor: .blue
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 20)

                // Carousel content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        CarouselPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Action button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        isPresented = false
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct CarouselPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

struct CarouselPageView: View {
    let page: CarouselPage

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(page.accentColor)
                .padding(.bottom, 20)

            // Title
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Description
            Text(page.description)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

#Preview {
    WelcomeCarouselView(isPresented: .constant(true))
}
