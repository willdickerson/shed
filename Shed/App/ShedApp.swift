//
//  ShedApp.swift
//  Shed
//

import SwiftUI

@main
struct ShedApp: App {
    @NSApplicationDelegateAdaptor(MenuIconStripper.self) private var appDelegate
    @State private var viewModel = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowToolbarStyle(.unified)
        .commands {
            // Replaces the default "New Window" with the import commands.
            CommandGroup(replacing: .newItem) {
                Button("Open Audio File…") { viewModel.requestOpenFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Menu("Open Recent") {
                    if viewModel.recentTracks.isEmpty {
                        Button("No Recent Files") {}.disabled(true)
                    } else {
                        ForEach(viewModel.recentTracks) { item in
                            Button(item.name) { viewModel.openRecent(item) }
                        }
                        Divider()
                        Button("Clear Menu") { viewModel.clearRecentFiles() }
                    }
                }
                Button("Import from YouTube…") { viewModel.requestYouTubeImport() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Show in Finder") { viewModel.revealCurrentFileInFinder() }
                    .disabled(!viewModel.hasTrack)
            }
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

/// Removes the SF Symbol icons macOS automatically adds to standard menu
/// commands (e.g. the ✕ on Close), keeping the menus consistently text-only.
/// Re-runs whenever a menu starts tracking, so it survives menu rebuilds.
final class MenuIconStripper: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self, selector: #selector(strip),
            name: NSMenu.didBeginTrackingNotification, object: nil)
        strip()
    }

    @objc private func strip() {
        clearImages(in: NSApp.mainMenu)
    }

    private func clearImages(in menu: NSMenu?) {
        guard let menu else { return }
        for item in menu.items {
            if item.image != nil { item.image = nil }
            clearImages(in: item.submenu)
        }
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
