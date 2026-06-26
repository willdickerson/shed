//
//  RootView.swift
//  Shed
//
//  Top-level layout: import bar on top, waveform + inspector in the middle,
//  transport at the bottom. Also wires up keyboard shortcuts and error alerts.
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Bindable var viewModel: WorkspaceViewModel

    @State private var showFileImporter = false
    @FocusState private var keyboardFocused: Bool

    private static let importTypes: [UTType] = [.audio, .movie, .mpeg4Movie, .quickTimeMovie]

    var body: some View {
        VStack(spacing: 0) {
            ImportBar(
                viewModel: viewModel,
                onOpenFile: { showFileImporter = true }
            )
            Divider()

            HSplitView {
                WaveformPane(viewModel: viewModel, onInteract: { keyboardFocused = true })
                    .frame(minWidth: 480)

                InspectorView(viewModel: viewModel)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            }

            Divider()
            TransportBar(viewModel: viewModel)
        }
        .focusable()
        .focused($keyboardFocused)
        .focusEffectDisabled()
        .onAppear { keyboardFocused = true }
        .modifier(KeyboardShortcuts(viewModel: viewModel))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: Self.importTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert(
            "Shed",
            isPresented: Binding(
                get: { viewModel.activeError != nil },
                set: { if !$0 { viewModel.activeError = nil } }
            ),
            presenting: viewModel.activeError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            viewModel.importLocalFile(at: url)
        case let .failure(error):
            viewModel.activeError = PresentedError(message: error.localizedDescription)
        }
    }
}
