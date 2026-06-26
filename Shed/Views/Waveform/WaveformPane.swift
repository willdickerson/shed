//
//  WaveformPane.swift
//  Shed
//
//  Stacks the main waveform, the time ruler, and the overview strip.
//

import SwiftUI

struct WaveformPane: View {
    @Bindable var viewModel: WorkspaceViewModel
    @Binding var viewport: Viewport
    let onInteract: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let waveform = viewModel.waveform {
                WaveformView(viewModel: viewModel, waveform: waveform,
                             viewport: $viewport, onInteract: onInteract)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                TimeRulerView(viewport: viewport, duration: viewModel.duration)
                    .frame(height: 14)

                OverviewWaveformView(waveform: waveform, viewport: $viewport, duration: viewModel.duration)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
