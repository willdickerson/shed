//
//  KeyboardShortcuts.swift
//  Shed
//
//  Maps single-key shortcuts to workspace actions. Active only while the main
//  content has focus, so typing in the URL field is never intercepted.
//

import AppKit
import SwiftUI

struct KeyboardShortcuts: ViewModifier {
    let viewModel: WorkspaceViewModel
    var focus: FocusState<Bool>.Binding
    var onZoomIn: () -> Void = {}
    var onZoomOut: () -> Void = {}

    enum Key {
        case space, leftArrow, rightArrow, returnKey, escape
        case character(String)
    }

    func body(content: Content) -> some View {
        if #available(macOS 14, *) {
            content
                .focusable()
                .focused(focus)
                .focusEffectDisabled()
                .onKeyPress { press in
                    handle(Self.key(for: press), command: press.modifiers.contains(.command))
                        ? .handled : .ignored
                }
        } else {
            // No onKeyPress on Ventura: watch key-downs in the main window
            // instead, skipping them while a text field is being edited.
            content.background(KeyDownMonitor { event in
                guard let key = Self.key(for: event) else { return false }
                return handle(key, command: event.modifierFlags.contains(.command))
            })
        }
    }

    /// Runs the action bound to `key`; returns whether it was handled.
    private func handle(_ key: Key, command: Bool) -> Bool {
        // ⌘-combinations: zoom and undo. Other ⌘ keys fall through to menus.
        if command {
            guard case let .character(char) = key else { return false }
            switch char {
            case "=", "+": onZoomIn()
            case "-", "_": onZoomOut()
            case "z", "Z": viewModel.undoLoop()
            default: return false
            }
            return true
        }

        switch key {
        case .space: viewModel.togglePlayPause()
        case .leftArrow: viewModel.skipBackward()
        case .rightArrow: viewModel.skipForward()
        case .returnKey: viewModel.returnToStart()
        case .escape: viewModel.clearLoop()
        case let .character(char):
            switch char.lowercased() {
            case "l": viewModel.toggleLoop()
            case "[": viewModel.setLoopStartAtPlayhead()
            case "]": viewModel.setLoopEndAtPlayhead()
            case "-", "_": viewModel.decreaseSpeed()
            case "=", "+": viewModel.increaseSpeed()
            default: return false
            }
        }
        return true
    }

    @available(macOS 14, *)
    private static func key(for press: KeyPress) -> Key {
        switch press.key {
        case .space: return .space
        case .leftArrow: return .leftArrow
        case .rightArrow: return .rightArrow
        case .return: return .returnKey
        case .escape: return .escape
        default:
            return .character(press.modifiers.contains(.command)
                              ? String(press.key.character) : press.characters)
        }
    }

    private static func key(for event: NSEvent) -> Key? {
        switch event.keyCode {
        case 49: return .space
        case 123: return .leftArrow
        case 124: return .rightArrow
        case 36, 76: return .returnKey
        case 53: return .escape
        default:
            let chars = event.modifierFlags.contains(.command)
                ? event.charactersIgnoringModifiers : event.characters
            return chars.map(Key.character)
        }
    }
}

/// Local key-down monitor scoped to the hosting window.
private struct KeyDownMonitor: NSViewRepresentable {
    /// Returns true when the event was handled and should be swallowed.
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ view: MonitorView, context: Context) {
        view.onKeyDown = onKeyDown
    }

    final class MonitorView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self, let window = self.window, event.window === window,
                          !(window.firstResponder is NSText),
                          self.onKeyDown?(event) == true
                    else { return event }
                    return nil
                }
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
