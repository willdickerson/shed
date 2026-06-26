//
//  WaveformPane.swift
//  Shed
//
//  Switches between the empty state and the live waveform.
//

import SwiftUI

struct WaveformPane: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onInteract: () -> Void

    var body: some View {
        Group {
            if let waveform = viewModel.waveform, viewModel.hasTrack {
                WaveformView(viewModel: viewModel, waveform: waveform, onInteract: onInteract)
                    .padding(16)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
