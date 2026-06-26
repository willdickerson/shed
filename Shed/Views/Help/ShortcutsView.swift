//
//  ShortcutsView.swift
//  Shed
//
//  Reference sheet of keyboard shortcuts, opened from the Help menu (⌘/).
//

import SwiftUI

struct ShortcutsView: View {
    private struct Shortcut: Identifiable {
        let id = UUID()
        let keys: String
        let action: String
    }

    private let shortcuts: [Shortcut] = [
        .init(keys: "Space", action: "Play / Pause"),
        .init(keys: "←", action: "Back 5 seconds"),
        .init(keys: "→", action: "Forward 5 seconds"),
        .init(keys: "L", action: "Toggle loop"),
        .init(keys: "Esc", action: "Clear loop"),
        .init(keys: "[", action: "Set loop start"),
        .init(keys: "]", action: "Set loop end"),
        .init(keys: "−", action: "Slower"),
        .init(keys: "=", action: "Faster")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.title2.weight(.semibold))

            VStack(spacing: 10) {
                ForEach(shortcuts) { shortcut in
                    HStack {
                        Text(shortcut.action)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 32)
                        Text(shortcut.keys)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 320)
    }
}
