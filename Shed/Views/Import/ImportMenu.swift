//
//  ImportMenu.swift
//  Shed
//
//  The single import entry point, shared by the toolbar and the empty state.
//

import SwiftUI

struct ImportMenu: View {
    let onOpenFile: () -> Void
    let onYouTube: () -> Void
    var prominent = false

    var body: some View {
        Menu {
            Button("Open Audio File…", systemImage: "folder", action: onOpenFile)
            Button("Import from YouTube…", systemImage: "play.rectangle", action: onYouTube)
        } label: {
            Label("Import", systemImage: "folder.badge.plus")
        }
        .modifier(StyleModifier(prominent: prominent))
    }

    private struct StyleModifier: ViewModifier {
        let prominent: Bool
        func body(content: Content) -> some View {
            if prominent {
                content
                    .menuStyle(.button)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .menuIndicator(.hidden)
            } else {
                content
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .fixedSize()
            }
        }
    }
}
