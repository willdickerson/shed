//
//  TransportBar.swift
//  Shed
//

import SwiftUI

struct TransportBar: View {
    @Bindable var viewModel: WorkspaceViewModel

    var body: some View {
        HStack(spacing: 16) {
            timeLabel(viewModel.currentTime)
                .frame(width: 64, alignment: .leading)

            Spacer()

            HStack(spacing: 18) {
                transportButton("stop.fill", help: "Stop", action: viewModel.stop)
                transportButton("gobackward.5", help: "Back 5 seconds", action: viewModel.skipBackward)

                Button(action: viewModel.togglePlayPause) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 30)
                }
                .buttonStyle(.plain)
                .help(viewModel.isPlaying ? "Pause" : "Play")

                transportButton("goforward.5", help: "Forward 5 seconds", action: viewModel.skipForward)

                Button(action: viewModel.toggleLoop) {
                    Image(systemName: "repeat")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.loopEnabled ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .help("Toggle loop (L)")
            }
            .disabled(!viewModel.hasTrack)

            Spacer()

            timeLabel(viewModel.duration)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func transportButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func timeLabel(_ seconds: TimeInterval) -> some View {
        Text(TimeFormatting.clock(seconds))
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}
