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
            VStack(alignment: .leading, spacing: 20) {
                fileSection
                playbackSection
                loopSection
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

            VStack(alignment: .leading, spacing: 7) {
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
                .toggleStyle(.switch)
                .padding(.top, 2)

            Button("Clear Loop") { viewModel.clearLoop() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.loopRegion == nil)
                .padding(.top, 4)
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

/// An inspector group: a quiet header above a rounded card holding its rows.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 11) {
                content
            }
            .padding(14)
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
