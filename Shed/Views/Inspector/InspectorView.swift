//
//  InspectorView.swift
//  Shed
//
//  Right-hand panel: track metadata plus speed, pitch, and loop controls.
//

import SwiftUI

struct InspectorView: View {
    @Bindable var viewModel: WorkspaceViewModel

    var body: some View {
        Form {
            trackSection
            playbackSection
            loopSection
        }
        .formStyle(.grouped)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Track

    private var trackSection: some View {
        Section("Track") {
            InspectorRow(label: "File", value: viewModel.track?.displayName ?? "—")
            InspectorRow(label: "Source", value: viewModel.track?.source.displayName ?? "—")
            InspectorRow(label: "Duration", value: TimeFormatting.clock(viewModel.duration))
            InspectorRow(label: "Position", value: TimeFormatting.clock(viewModel.currentTime))
            InspectorRow(label: "Status", value: statusText)
        }
    }

    private var statusText: String {
        viewModel.importStatus == .idle ? "—" : viewModel.importStatus.label
    }

    // MARK: - Playback

    private var playbackSection: some View {
        Section("Playback") {
            Picker("Speed", selection: speedBinding) {
                ForEach(WorkspaceViewModel.speedOptions, id: \.self) { option in
                    Text("\(Int(option * 100))%").tag(option)
                }
            }

            Stepper(value: semitoneBinding, in: -12...12) {
                InspectorRow(label: "Semitones", value: signed(viewModel.semitones))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cents").foregroundStyle(.secondary)
                    Spacer()
                    Text(signed(viewModel.cents))
                }
                .font(.callout)
                Slider(value: centsBinding, in: -100...100, step: 1)
            }
        }
    }

    // MARK: - Loop

    private var loopSection: some View {
        Section("Loop") {
            InspectorRow(label: "Start", value: loopValue(viewModel.loopRegion?.start))
            InspectorRow(label: "End", value: loopValue(viewModel.loopRegion?.end))

            Toggle("Loop Enabled", isOn: loopBinding)

            Button(role: .destructive) {
                viewModel.clearLoop()
            } label: {
                Text("Clear Loop")
            }
            .disabled(viewModel.loopRegion == nil)
        }
    }

    // MARK: - Bindings & formatting

    private var speedBinding: Binding<Double> {
        Binding(get: { viewModel.speed }, set: { viewModel.setSpeed($0) })
    }

    private var semitoneBinding: Binding<Int> {
        Binding(get: { viewModel.semitones }, set: { viewModel.setSemitones($0) })
    }

    private var centsBinding: Binding<Double> {
        Binding(get: { Double(viewModel.cents) }, set: { viewModel.setCents(Int($0.rounded())) })
    }

    private var loopBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loopEnabled },
            set: { newValue in
                if newValue != viewModel.loopEnabled { viewModel.toggleLoop() }
            }
        )
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func loopValue(_ time: TimeInterval?) -> String {
        guard let time else { return "—" }
        return TimeFormatting.precise(time)
    }
}
