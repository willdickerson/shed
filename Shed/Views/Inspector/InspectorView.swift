//
//  InspectorView.swift
//  Shed
//
//  A spacious, scannable inspector in the spirit of Logic / Final Cut / Xcode
//  panels — grouped cards rather than a property table. Speed lives in the
//  transport bar since it's adjusted constantly.
//

import SwiftUI

struct InspectorView: View {
    @Bindable var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                trackSection
                playbackSection
                loopSection
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Track

    private var trackSection: some View {
        InspectorSection("Track") {
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.track?.displayName ?? "—")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trackSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trackSubtitle: String {
        guard let track = viewModel.track else { return "" }
        return "\(track.source.displayName) • \(TimeFormatting.clock(track.duration))"
    }

    // MARK: - Playback

    private var playbackSection: some View {
        InspectorSection("Pitch") {
            stepperGroup(
                title: "Semitones",
                value: signed(viewModel.semitones),
                canDecrement: viewModel.semitones > -12,
                decrement: { viewModel.setSemitones(viewModel.semitones - 1) },
                canIncrement: viewModel.semitones < 12,
                increment: { viewModel.setSemitones(viewModel.semitones + 1) }
            )

            stepperGroup(
                title: "Cents",
                value: signed(viewModel.cents),
                canDecrement: viewModel.cents > -100,
                decrement: { viewModel.setCents(viewModel.cents - 1) },
                canIncrement: viewModel.cents < 100,
                increment: { viewModel.setCents(viewModel.cents + 1) }
            )

            Button {
                viewModel.resetPitch()
            } label: {
                Label("Reset Pitch", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(!viewModel.isPitchAdjusted)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)

            Divider().padding(.vertical, 2)

            tuningControl
                .animation(.easeInOut(duration: 0.22), value: viewModel.tuningState)
        }
    }

    // MARK: - Tuning

    private let inTuneThreshold = 3

    @ViewBuilder
    private var tuningControl: some View {
        switch viewModel.tuningState {
        case .idle:
            Button("Detect Tuning Offset") { viewModel.findTuningOffset() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

        case .analyzing:
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative)
                Text("Estimating offset…")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)

        case let .result(estimate):
            resultPanel(estimate)
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .applied:
            Label("Correction Applied", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .transition(.opacity)

        case .failed:
            VStack(spacing: 4) {
                Text("Unable to estimate tuning")
                    .font(.callout.weight(.medium))
                Text("This recording does not contain enough stable pitched material.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private func resultPanel(_ estimate: TuningEstimate) -> some View {
        let cents = Int(estimate.offsetCents.rounded())
        let inTune = abs(cents) <= inTuneThreshold

        VStack(spacing: 12) {
            VStack(spacing: 3) {
                Text("Estimated tuning")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(inTune
                     ? "Recording appears to be in tune."
                     : "Recording is \(abs(cents)) cents \(cents < 0 ? "flat" : "sharp").")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Based on approximately \(estimate.detectionCount.formatted()) stable note detections.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            if !inTune {
                let correction = -cents
                Button("Apply \(correction > 0 ? "+" : "")\(correction) cent Correction") {
                    withAnimation(.easeInOut(duration: 0.18)) { viewModel.applyTuningCorrection() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func stepperGroup(title: String, value: String,
                              canDecrement: Bool, decrement: @escaping () -> Void,
                              canIncrement: Bool, increment: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                adjustButton("minus", enabled: canDecrement, action: decrement)
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .monospacedDigit()
                    .frame(width: 46)
                adjustButton("plus", enabled: canIncrement, action: increment)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func adjustButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!enabled)
    }

    // MARK: - Loop

    private var loopSection: some View {
        InspectorSection("Loop") {
            VStack(spacing: 9) {
                InspectorRow(label: "Start", value: loopTime(viewModel.loopRegion?.start))
                InspectorRow(label: "End", value: loopTime(viewModel.loopRegion?.end))
                InspectorRow(label: "Length", value: loopLength(viewModel.loopRegion?.duration))
            }

            Divider()
                .padding(.vertical, 2)

            Toggle("", isOn: loopBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .center)

            Button("Clear Loop") { viewModel.clearLoop() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.loopRegion == nil)
                .padding(.top, 2)
        }
    }

    // MARK: - Bindings & formatting

    private var loopBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loopEnabled },
            set: { newValue in if newValue != viewModel.loopEnabled { viewModel.toggleLoop() } }
        )
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private func loopTime(_ time: TimeInterval?) -> String {
        guard let time else { return "—" }
        return TimeFormatting.precise(time)
    }

    private func loopLength(_ duration: TimeInterval?) -> String {
        guard let duration else { return "—" }
        if duration < 60 { return String(format: "%.1f s", duration) }
        return TimeFormatting.precise(duration)
    }
}

/// An inspector group: a quiet header above a rounded card holding its content.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}
