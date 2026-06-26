//
//  InspectorView.swift
//  Shed
//
//  Calm, low-chrome inspector: File, Playback (pitch), Loop. Speed lives in the
//  transport bar since it's adjusted constantly.
//

import SwiftUI

struct InspectorView: View {
    @Bindable var viewModel: WorkspaceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                fileSection
                playbackSection
                loopSection
            }
            .padding(20)
        }
    }

    // MARK: - File

    private var fileSection: some View {
        InspectorSection("File") {
            InspectorRow(label: "Name", value: viewModel.track?.displayName ?? "—")
            InspectorRow(label: "Source", value: viewModel.track?.source.displayName ?? "—")
            InspectorRow(label: "Duration", value: TimeFormatting.clock(viewModel.duration))
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        InspectorSection("Playback") {
            Stepper(value: semitoneBinding, in: -12...12) {
                InspectorRow(label: "Semitones", value: signed(viewModel.semitones))
            }

            VStack(alignment: .leading, spacing: 6) {
                InspectorRow(label: "Cents", value: signed(viewModel.cents))
                Slider(value: centsBinding, in: -100...100, step: 1)
            }
        }
    }

    // MARK: - Loop

    private var loopSection: some View {
        InspectorSection("Loop") {
            InspectorRow(label: "Start", value: loopValue(viewModel.loopRegion?.start))
            InspectorRow(label: "End", value: loopValue(viewModel.loopRegion?.end))
            InspectorRow(label: "Length", value: loopValue(viewModel.loopRegion?.duration))

            Toggle("Loop Enabled", isOn: loopBinding)
                .padding(.top, 2)

            Button("Clear Loop") { viewModel.clearLoop() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.loopRegion == nil)
                .padding(.top, 2)
        }
    }

    // MARK: - Bindings & formatting

    private var semitoneBinding: Binding<Int> {
        Binding(get: { viewModel.semitones }, set: { viewModel.setSemitones($0) })
    }

    private var centsBinding: Binding<Double> {
        Binding(get: { Double(viewModel.cents) }, set: { viewModel.setCents(Int($0.rounded())) })
    }

    private var loopBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loopEnabled },
            set: { newValue in if newValue != viewModel.loopEnabled { viewModel.toggleLoop() } }
        )
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

    private func loopValue(_ time: TimeInterval?) -> String {
        guard let time else { return "—" }
        return TimeFormatting.precise(time)
    }
}

/// A lightweight inspector section: small uppercase-ish header over its rows.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}
