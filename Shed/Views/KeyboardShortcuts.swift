//
//  KeyboardShortcuts.swift
//  Shed
//
//  Maps single-key shortcuts to workspace actions. Active only while the main
//  content has focus, so typing in the URL field is never intercepted.
//

import SwiftUI

struct KeyboardShortcuts: ViewModifier {
    let viewModel: WorkspaceViewModel
    var onZoomIn: () -> Void = {}
    var onZoomOut: () -> Void = {}

    func body(content: Content) -> some View {
        content.onKeyPress { press in
            // ⌘-combinations: zoom and undo. Other ⌘ keys fall through to menus.
            if press.modifiers.contains(.command) {
                switch press.key {
                case KeyEquivalent("="), KeyEquivalent("+"):
                    onZoomIn(); return .handled
                case KeyEquivalent("-"), KeyEquivalent("_"):
                    onZoomOut(); return .handled
                case KeyEquivalent("z"), KeyEquivalent("Z"):
                    viewModel.undoLoop(); return .handled
                default:
                    return .ignored
                }
            }

            switch press.key {
            case .space:
                viewModel.togglePlayPause(); return .handled
            case .leftArrow:
                viewModel.skipBackward(); return .handled
            case .rightArrow:
                viewModel.skipForward(); return .handled
            case .return:
                viewModel.returnToStart(); return .handled
            case .escape:
                viewModel.clearLoop(); return .handled
            default:
                break
            }

            switch press.characters.lowercased() {
            case "l":
                viewModel.toggleLoop(); return .handled
            case "[":
                viewModel.setLoopStartAtPlayhead(); return .handled
            case "]":
                viewModel.setLoopEndAtPlayhead(); return .handled
            case "-", "_":
                viewModel.decreaseSpeed(); return .handled
            case "=", "+":
                viewModel.increaseSpeed(); return .handled
            default:
                return .ignored
            }
        }
    }
}
