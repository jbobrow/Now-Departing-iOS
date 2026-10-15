//
//  PagedTabView.swift
//  Now Departing
//
//  A tab view whose pages can also be dragged between, with a bar that
//  stands in for the system tab bar (which can't be paged by swiping).
//

import SwiftUI

struct PagedTab: Identifiable {
    let id: Int
    let title: String
    let systemImage: String
}

struct PagedTabView<Page: View>: View {
    @Binding var selection: Int
    let tabs: [PagedTab]
    @ViewBuilder let page: (PagedTab) -> Page

    @State private var scrolledID: Int?
    @State private var progress: CGFloat        // continuous page position, for the bar's highlight
    @State private var coveredPages: Set<Int> = []
    @State private var reselectCounts: [Int: Int] = [:]
    @State private var leftCounts: [Int: Int] = [:]
    /// How far the bar reaches above the bottom safe area
    @State private var barInset: CGFloat = 0

    init(selection: Binding<Int>, tabs: [PagedTab], @ViewBuilder page: @escaping (PagedTab) -> Page) {
        _selection = selection
        self.tabs = tabs
        self.page = page
        _scrolledID = State(initialValue: selection.wrappedValue)
        _progress = State(initialValue: CGFloat(selection.wrappedValue))
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(tabs) { tab in
                    page(tab)
                        .containerRelativeFrame(.horizontal)
                        .environment(\.pagedTabRootReporter, PagedTabRootReporter(page: tab.id) { visible in
                            if visible {
                                coveredPages.remove(tab.id)
                            } else if tab.id == selection {
                                coveredPages.insert(tab.id)   // pages scrolled away also disappear; that's no push
                            }
                        })
                        .environment(\.pagedTabReselectCount, reselectCounts[tab.id, default: 0])
                        .environment(\.pagedTabLeftCount, leftCounts[tab.id, default: 0])
                        .environment(\.pagedTabBarInset, barInset)
                        .id(tab.id)
                }
            }
            .scrollTargetLayout()
            .background(PagerEdgeGate())
            // scrollDisabled below flows down to every list inside; only the pager should stop
            .environment(\.isScrollEnabled, true)
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledID)
        .scrollIndicators(.hidden)
        // While a page has something pushed, leave horizontal drags to the back swipe
        .scrollDisabled(coveredPages.contains(selection))
        .trackingPageProgress($progress)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PagedTabBar(tabs: tabs, progress: progress) { id in
                if id == scrolledID {
                    reselectCounts[id, default: 0] += 1
                } else {
                    withAnimation(.smooth(duration: 0.35)) { scrolledID = id }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barInset = $0 }
        }
        .onChange(of: scrolledID) { _, id in
            guard let id else { return }
            selection = id
            if #unavailable(iOS 18.0) { progress = CGFloat(id) }
        }
        .onChange(of: selection) { oldID, id in
            if scrolledID != id { scrolledID = id }
            // Once the page just left has slid out of sight, take it back to its first screen,
            // so every page is arrived at from the top
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if selection != oldID { leftCounts[oldID, default: 0] += 1 }
            }
        }
    }
}

// MARK: - Bar

private struct PagedTabBar: View {
    let tabs: [PagedTab]
    let progress: CGFloat
    let onSelect: (Int) -> Void

    private let itemWidth: CGFloat = 90
    private let itemHeight: CGFloat = 54
    private let barPadding: CGFloat = 4

    /// Where a finger holds the highlight while dragging along the bar, in tab units
    @State private var dragPosition: CGFloat?
    /// The tab just chosen on the bar; the highlight waits there while the pages catch up
    @State private var pendingID: Int?

    private var lastIndex: CGFloat { CGFloat(tabs.count - 1) }

    /// The highlight's position in tab units
    private var highlightPosition: CGFloat {
        if let dragPosition { return dragPosition }
        if let pendingID { return CGFloat(pendingID) }
        return min(max(progress, 0), lastIndex)
    }

    private var selectedID: Int { tabs[Int(highlightPosition.rounded())].id }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                floatingBar
            } else {
                classicBar
            }
        }
        .onChange(of: progress) { _, newProgress in
            if let pendingID, abs(newProgress - CGFloat(pendingID)) < 0.01 {
                self.pendingID = nil
            }
        }
    }

    // A floating Liquid Glass bar. Its highlight follows the pages as they're dragged, and can
    // itself be dragged along the bar to switch tabs.
    @available(iOS 26.0, *)
    private var floatingBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                itemLabel(tab, tinted: tab.id == selectedID)
                    .frame(width: itemWidth, height: itemHeight)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(tab.id == selectedID ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { select(tab.id) }
            }
        }
        .background(alignment: .leading) {
            Capsule()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: itemWidth, height: itemHeight)
                .offset(x: highlightPosition * itemWidth)
        }
        .padding(barPadding)
        .contentShape(.capsule)
        .gesture(barDrag)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, -8)   // sits partway into the home indicator's area, like the system bar
    }

    private var barDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Center the highlight under the finger, kept within the bar
                let position = (value.location.x - barPadding) / itemWidth - 0.5
                let clamped = min(max(position, 0), lastIndex)
                withAnimation(dragPosition == nil ? .spring(response: 0.3, dampingFraction: 0.7)
                                                  : .interactiveSpring(response: 0.2, dampingFraction: 0.85)) {
                    dragPosition = clamped
                }
            }
            .onEnded { value in
                let isTap = hypot(value.translation.width, value.translation.height) < 10
                select(selectedID, isTap: isTap)
            }
    }

    /// A slide that comes back to the current tab just settles; only a tap there counts as tapping it again
    private func select(_ id: Int, isTap: Bool = true) {
        let isCurrent = abs(progress - CGFloat(id)) <= 0.01
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            dragPosition = nil
            if !isCurrent { pendingID = id }
        }
        if isCurrent && !isTap { return }
        onSelect(id)
        // In case the pages never settle on it (another drag, say), stop holding the highlight
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if pendingID == id {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pendingID = nil }
            }
        }
    }

    private var classicBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    select(tab.id)
                } label: {
                    itemLabel(tab, tinted: tab.id == selectedID)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(tab.id == selectedID ? .isSelected : [])
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 2)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func itemLabel(_ tab: PagedTab, tinted: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 21, weight: .medium))
                .frame(height: 26)
            Text(tab.title)
                .font(.system(size: 10, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(tinted ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .contentShape(.rect)
    }
}

// MARK: - Edge Gate

/// Keeps the pager from claiming drags that head past its first or last page, so they reach
/// the rows instead: Nearby's swipe-right to favorite and Favorites' swipe-left to delete.
private struct PagerEdgeGate: UIViewRepresentable {
    func makeUIView(context: Context) -> GateInstallerView {
        let view = GateInstallerView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: GateInstallerView, context: Context) {}

    final class GateInstallerView: UIView {
        private let gate = UIPanGestureRecognizer()
        private let gateDelegate = GateDelegate()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard gateDelegate.pager == nil, window != nil else { return }

            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            guard let scrollView = ancestor as? UIScrollView else { return }

            gateDelegate.pager = scrollView
            gate.delegate = gateDelegate
            gate.cancelsTouchesInView = false
            scrollView.addGestureRecognizer(gate)
            // The pager's pan waits on the gate's call about which way the drag is heading
            scrollView.panGestureRecognizer.require(toFail: gate)
        }
    }

    final class GateDelegate: NSObject, UIGestureRecognizerDelegate {
        weak var pager: UIScrollView?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pager, let gate = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = gate.velocity(in: pager)
            guard abs(velocity.x) > abs(velocity.y) else { return false }

            let offset = pager.contentOffset.x
            let maxOffset = pager.contentSize.width - pager.bounds.width
            let atFirstPage = offset <= 1
            let atLastPage = offset >= maxOffset - 1
            if (velocity.x > 0 && atFirstPage) || (velocity.x < 0 && atLastPage) {
                // Sit this touch out. Recognizing instead would also hold off the row's swipe.
                let pan = pager.panGestureRecognizer
                pan.isEnabled = false
                DispatchQueue.main.async { pan.isEnabled = true }
            }
            // Never claims the drag itself
            return false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

// MARK: - Root Tracking

/// Set by PagedTabView on each page; that page's navigation root reports when it shows and hides.
struct PagedTabRootReporter: Equatable {
    let page: Int
    let report: (Bool) -> Void

    // The closure only writes the pager's state, so the page identifies it
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.page == rhs.page }
}

extension EnvironmentValues {
    @Entry var pagedTabRootReporter: PagedTabRootReporter?
    /// Goes up each time the page's tab is tapped while it's already showing, e.g. to pop to root.
    @Entry var pagedTabReselectCount = 0
    /// Goes up each time the pager has moved off the page and it's out of sight.
    @Entry var pagedTabLeftCount = 0
    /// How far the bar reaches above the bottom safe area. The bar floats over the pages and
    /// their safe area doesn't make room for it, so their lists add this at the bottom.
    @Entry var pagedTabBarInset: CGFloat = 0
}

extension View {
    /// Marks the root of a page's NavigationStack. Paging pauses while the root is covered by a pushed view.
    func pagedTabRoot() -> some View {
        modifier(PagedTabRootModifier())
    }

    /// Room at the end of a list for the bar, so its last rows can scroll out from under it
    func clearsPagedTabBar() -> some View {
        modifier(PagedTabBarClearance())
    }

    /// Calls `popToRoot` when the page's tab is tapped again while it's showing, and, without
    /// animation, once the pager has left the page.
    func pagedTabPopsToRoot(_ popToRoot: @escaping () -> Void) -> some View {
        modifier(PagedTabPopModifier(popToRoot: popToRoot))
    }
}

private struct PagedTabBarClearance: ViewModifier {
    @Environment(\.pagedTabBarInset) private var barInset

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: barInset)
        }
    }
}

private struct PagedTabPopModifier: ViewModifier {
    let popToRoot: () -> Void
    @Environment(\.pagedTabReselectCount) private var reselectCount
    @Environment(\.pagedTabLeftCount) private var leftCount

    func body(content: Content) -> some View {
        content
            .onChange(of: reselectCount) { popToRoot() }
            .onChange(of: leftCount) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction, popToRoot)
            }
    }
}

private struct PagedTabRootModifier: ViewModifier {
    @Environment(\.pagedTabRootReporter) private var reporter

    func body(content: Content) -> some View {
        content
            .background(NavigationBarMarginFix())
            .onAppear { reporter?.report(true) }
            .onDisappear { reporter?.report(false) }
    }
}

/// Inside the pager's scroll view, UIKit gives each page's navigation controller no minimum side
/// margins, which runs large titles into the screen edge. This restores the usual margins.
private struct NavigationBarMarginFix: UIViewRepresentable {
    func makeUIView(context: Context) -> FixView {
        let view = FixView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: FixView, context: Context) {}

    final class FixView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }

            var responder: UIResponder? = self
            while let current = responder, !(current is UINavigationController) { responder = current.next }
            guard let navigationController = responder as? UINavigationController,
                  let host = navigationController.parent else { return }

            let minimum = host.systemMinimumLayoutMargins
            navigationController.navigationBar.directionalLayoutMargins.leading = minimum.leading
            navigationController.navigationBar.directionalLayoutMargins.trailing = minimum.trailing
        }
    }
}

private extension View {
    @ViewBuilder
    func trackingPageProgress(_ progress: Binding<CGFloat>) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.containerSize.width > 0 ? geometry.contentOffset.x / geometry.containerSize.width : 0
            } action: { _, newValue in
                progress.wrappedValue = newValue
            }
        } else {
            self
        }
    }
}
