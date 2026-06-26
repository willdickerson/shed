//
//  TransportBar.swift
//  Shed
//
//  Bottom transport: zoom (leading), play/seek + time + speed (center),
//  volume (trailing). Play is the dominant control.
//

import SwiftUI

struct TransportBar: View {
    @Bindable var viewModel: WorkspaceViewModel
    @Binding var viewport: Viewport

    var body: some View {
        HStack(spacing: 0) {
            zoomControl
                .frame(width: 200, alignment: .leading)

            Spacer(minLength: 16)

            HStack(spacing: 22) {
                seekButton("gobackward.5", help: "Back 5 seconds (←)", action: viewModel.skipBackward)
                playButton
                seekButton("goforward.5", help: "Forward 5 seconds (→)", action: viewModel.skipForward)

                timeReadout
                    .padding(.leading, 6)

                speedControl
            }
            .disabled(!viewModel.hasTrack)

            Spacer(minLength: 16)

            volumeControl
                .frame(width: 200, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Center

    private var playButton: some View {
        Button(action: viewModel.togglePlayPause) {
            ZStack {
                Circle().fill(Color.accentColor)
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: viewModel.isPlaying ? 0 : 1)
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .help(viewModel.isPlaying ? "Pause (Space)" : "Play (Space)")
    }

    private func seekButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var timeReadout: some View {
        HStack(spacing: 4) {
            Text(TimeFormatting.clock(viewModel.currentTime))
                .foregroundStyle(.primary)
            Text("/")
                .foregroundStyle(.tertiary)
            Text(TimeFormatting.clock(viewModel.duration))
                .foregroundStyle(.secondary)
        }
        .font(.system(.callout, design: .rounded))
        .monospacedDigit()
    }

    private var speedControl: some View {
        HStack(spacing: 8) {
            stepperButton("minus", help: "Slower (−)", enabled: viewModel.speed > WorkspaceViewModel.speedOptions.first ?? 0.5) {
                viewModel.decreaseSpeed()
            }
            Text(viewModel.speedPercent)
                .font(.system(.callout, design: .rounded).weight(.medium))
                .monospacedDigit()
                .frame(width: 42)
            stepperButton("plus", help: "Faster (=)", enabled: viewModel.speed < (WorkspaceViewModel.speedOptions.last ?? 1.0)) {
                viewModel.increaseSpeed()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.6), in: Capsule())
    }

    private func stepperButton(_ symbol: String, help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }

    // MARK: - Zoom

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
            Slider(value: $viewport.zoom, in: 1...Viewport.maxZoom)
            Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .disabled(!viewModel.hasTrack)
    }

    // MARK: - Volume

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: Binding(get: { viewModel.volume }, set: { viewModel.setVolume($0) }), in: 0...1)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .disabled(!viewModel.hasTrack)
    }
}
