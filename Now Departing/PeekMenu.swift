//
//  PeekMenu.swift
//  Now Departing
//
//  A long-press menu whose preview has parts you can tap. SwiftUI's
//  contextMenu preview takes no taps of its own: tapping anywhere on it only
//  dismisses the menu. Parts marked with peekTapTarget(_:) report which one
//  was tapped instead.
//

import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// MARK: - Tap Targets

private let peekCoordinateSpace = "peekPreview"

private struct PeekTapTargetsKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] = [:]

    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks part of a peekMenu preview. Tapping it passes `id` to the menu's onPreviewTap.
    func peekTapTarget(_ id: some Hashable) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(
                key: PeekTapTargetsKey.self,
                value: [AnyHashable(id): proxy.frame(in: .named(peekCoordinateSpace))]
            )
        })
    }

    /// Like contextMenu(menuItems:preview:) for a round label, but tapping the preview calls
    /// `onPreviewTap` with the peekTapTarget under the tap, or nil for anywhere else.
    /// The label is hosted on its own, so set its environment (say, disabled) before this.
    func peekMenu<Preview: View>(
        isEnabled: Bool = true,
        actions: @escaping () -> [UIMenuElement],
        preview: @escaping () -> Preview,
        onPreviewTap: @escaping (AnyHashable?) -> Void
    ) -> some View {
        PeekMenuHost(
            label: self,
            isEnabled: isEnabled,
            actions: actions,
            preview: { AnyView(preview()) },
            onPreviewTap: onPreviewTap
        )
    }
}

// MARK: - Host

private struct PeekMenuHost<Label: View>: UIViewRepresentable {
    let label: Label
    let isEnabled: Bool
    let actions: () -> [UIMenuElement]
    let preview: () -> AnyView
    let onPreviewTap: (AnyHashable?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(label: UIHostingController(rootView: label))
    }

    func makeUIView(context: Context) -> UIView {
        let labelView = context.coordinator.label.view!
        labelView.backgroundColor = .clear
        labelView.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
        return labelView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.label.rootView = label
        context.coordinator.host = self
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        context.coordinator.label.sizeThatFits(in: CGSize(
            width: proposal.width ?? .infinity,
            height: proposal.height ?? .infinity
        ))
    }

    final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        let label: UIHostingController<Label>
        var host: PeekMenuHost?
        private weak var shownPreview: PeekPreviewController?

        init(label: UIHostingController<Label>) {
            self.label = label
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            guard let host, host.isEnabled else { return nil }
            return UIContextMenuConfiguration(identifier: nil, previewProvider: { [weak self] in
                let controller = PeekPreviewController(content: host.preview())
                self?.shownPreview = controller
                return controller
            }, actionProvider: { _ in
                UIMenu(children: host.actions())
            })
        }

        // Lift just the circle, not a rectangle around it
        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configuration: UIContextMenuConfiguration,
                                    highlightPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
            targetedPreview()
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configuration: UIContextMenuConfiguration,
                                    dismissalPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
            targetedPreview()
        }

        private func targetedPreview() -> UITargetedPreview? {
            guard let view = label.view, view.window != nil else { return nil }
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(ovalIn: view.bounds)
            return UITargetedPreview(view: view, parameters: parameters)
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                                    animator: any UIContextMenuInteractionCommitAnimating) {
            let target = shownPreview?.tappedTarget()
            animator.addCompletion { [weak self] in
                self?.host?.onPreviewTap(target)
            }
        }
    }
}

// MARK: - Preview

private final class PeekPreviewController: UIHostingController<PeekPreviewRoot> {
    private let targets = PeekTapTargets()
    private let touchObserver = TouchObserver()

    init(content: AnyView) {
        super.init(rootView: PeekPreviewRoot(content: content, targets: targets))
        sizingOptions = .preferredContentSize
        safeAreaRegions = []  // keeps the content's coordinates the same as the view's
        // Raised like SwiftUI's previews, so dark mode's backgrounds come out lighter
        traitOverrides.userInterfaceLevel = .elevated
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The menu doesn't pass taps through to its preview, so watch the window for them
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.window?.addGestureRecognizer(touchObserver)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        touchObserver.view?.removeGestureRecognizer(touchObserver)
    }

    /// The target under the last touch on the preview.
    func tappedTarget() -> AnyHashable? {
        guard let window = view.window, let location = touchObserver.location else { return nil }
        // The menu shows a mirror of this view while the view itself sits offscreen,
        // so read the tap from the preview-sized view under it
        var shown = window.hitTest(location, with: nil)
        while let candidate = shown, !candidate.bounds.size.isClose(to: view.bounds.size) {
            shown = candidate.superview
        }
        guard let shown else { return nil }
        let point = shown.convert(location, from: nil)
        return targets.frames.first { $0.value.contains(point) }?.key
    }
}

private extension CGSize {
    func isClose(to other: CGSize) -> Bool {
        abs(width - other.width) < 1 && abs(height - other.height) < 1
    }
}

private final class PeekTapTargets {
    var frames: [AnyHashable: CGRect] = [:]
}

private struct PeekPreviewRoot: View {
    let content: AnyView
    let targets: PeekTapTargets

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: peekCoordinateSpace)
            .onPreferenceChange(PeekTapTargetsKey.self) { targets.frames = $0 }
    }
}

/// Notes where each touch begins, in window coordinates, without taking part in gestures.
private final class TouchObserver: UIGestureRecognizer {
    private(set) var location: CGPoint?

    override init(target: Any? = nil, action: Selector? = nil) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        location = touches.first?.location(in: nil)
        state = .failed
    }
}
