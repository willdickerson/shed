//
//  YouTubeImportSheet.swift
//  Shed
//

import SwiftUI

struct YouTubeImportSheet: View {
    @Bindable var viewModel: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    private var trimmedURL: String {
        viewModel.youTubeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import from YouTube")
                    .font(.headline)
                Text("Paste a link and Shed will download its audio.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("https://www.youtube.com/watch?v=…", text: $viewModel.youTubeURLString)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit(start)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import", action: start)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedURL.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { fieldFocused = true }
    }

    private func start() {
        guard !trimmedURL.isEmpty else { return }
        dismiss()
        viewModel.importYouTube()
    }
}
