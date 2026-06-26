//
//  ShedApp.swift
//  Shed
//

import SwiftUI

@main
struct ShedApp: App {
    @State private var viewModel = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button(viewModel.isPlaying ? "Pause" : "Play") { viewModel.togglePlayPause() }
                Button("Stop") { viewModel.stop() }
                    .keyboardShortcut(".", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                ShortcutsHelpButton()
            }
        }

        Window("Keyboard Shortcuts", id: "shortcuts") {
            ShortcutsView()
        }
        .windowResizability(.contentSize)
    }
}

/// Help-menu entry that opens the keyboard-shortcuts window.
private struct ShortcutsHelpButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Shed Keyboard Shortcuts") {
            openWindow(id: "shortcuts")
        }
        .keyboardShortcut("/", modifiers: .command)
    }
}
