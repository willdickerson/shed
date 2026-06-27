//
//  RootView.swift
//  Shed
//
//  Top-level layout. When a track is loaded it shows the waveform workspace +
//  inspector + transport; otherwise a full-bleed empty state. Also hosts the
//  titlebar toolbar, keyboard shortcuts, the YouTube sheet, and error alerts.
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Bindable var viewModel: WorkspaceViewModel

    @State private var viewport = Viewport()
    @FocusState private var keyboardFocused: Bool

    private static let importTypes: [UTType] = [.audio, .movie, .mpeg4Movie, .quickTimeMovie]

    var body: some View {
        Group {
            if viewModel.hasTrack {
                workspace
            } else {
                EmptyStateView(
                    onOpenFile: { viewModel.requestOpenFile() },
                    onYouTube: { viewModel.requestYouTubeImport() }
                )
            }
        }
        .focusable()
        .focused($keyboardFocused)
        .focusEffectDisabled()
        .onAppear { keyboardFocused = true }
        .modifier(KeyboardShortcuts(viewModel: viewModel))
        .navigationTitle(viewModel.track?.displayName ?? "Shed")
        .navigationSubtitle(viewModel.trackSubtitle)
        .toolbar { toolbarContent }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: Self.importTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $viewModel.isShowingYouTubeSheet) {
            YouTubeImportSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.track?.id) { _, _ in
            viewport = Viewport()
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

    private var workspace: some View {
        VStack(spacing: 0) {
            HSplitView {
                WaveformPane(viewModel: viewModel, viewport: $viewport,
                             onInteract: { keyboardFocused = true })
                    .frame(minWidth: 520)
                    .background(Color(nsColor: .textBackgroundColor))

                InspectorView(viewModel: viewModel)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
            }

            Divider()
            TransportBar(viewModel: viewModel, viewport: $viewport)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ImportMenu(
                onOpenFile: { viewModel.requestOpenFile() },
                onYouTube: { viewModel.requestYouTubeImport() }
            )
        }
        ToolbarItem(placement: .primaryAction) {
            ImportStatusBadge(status: viewModel.importStatus)
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

/// Compact status indicator shown in the toolbar's trailing edge.
private struct ImportStatusBadge: View {
    let status: ImportStatus

    var body: some View {
        switch status {
        case .idle, .ready:
            // Only surfaced while it's meaningful — during import or on failure.
            EmptyView()
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        default:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(status.label).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
