//
//  EmptyStateView.swift
//  Shed
//

import SwiftUI

struct EmptyStateView: View {
    let onOpenFile: () -> Void
    let onYouTube: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "waveform")
                .font(.system(size: 68, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            Text("Open an audio file or import from YouTube to begin.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ImportMenu(onOpenFile: onOpenFile, onYouTube: onYouTube, prominent: true)
                .fixedSize()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
