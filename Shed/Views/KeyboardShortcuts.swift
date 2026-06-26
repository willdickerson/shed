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

    func body(content: Content) -> some View {
        content.onKeyPress { press in
            switch press.key {
            case .space:
                viewModel.togglePlayPause(); return .handled
            case .leftArrow:
                viewModel.skipBackward(); return .handled
            case .rightArrow:
                viewModel.skipForward(); return .handled
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
            default:
                return .ignored
            }
        }
    }
}
