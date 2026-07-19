//
//  ScrollWheelCatcher.swift
//  Shed
//
//  SwiftUI has no scroll-wheel modifier on macOS, so this drops an invisible
//  NSView into the hierarchy and watches the app's scroll events, reporting
//  the ones that happen over this view's frame.
//

import AppKit
import SwiftUI

struct ScrollWheelCatcher: NSViewRepresentable {
    /// Deltas are in points for trackpads; line-based wheel deltas are already
    /// scaled to points before this is called.
    let onScroll: (_ deltaX: CGFloat, _ deltaY: CGFloat) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onScroll = onScroll
    }

    final class CatcherView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        private var monitor: Any?

        /// Rough point height of one wheel "line", to put mouse wheels on the
        /// same scale as precise trackpad deltas.
        private static let lineHeight: CGFloat = 10

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    self?.handle(event)
                    return event
                }
            }

        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        private func handle(_ event: NSEvent) {
            guard let window, event.window === window else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.contains(point) else { return }
            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : Self.lineHeight
            onScroll?(event.scrollingDeltaX * scale, event.scrollingDeltaY * scale)
        }
    }
}
