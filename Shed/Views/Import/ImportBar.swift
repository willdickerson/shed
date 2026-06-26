//
//  ImportBar.swift
//  Shed
//

import SwiftUI

struct ImportBar: View {
    @Bindable var viewModel: WorkspaceViewModel
    let onOpenFile: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpenFile) {
                Label("Open File", systemImage: "folder")
            }
            .help("Open a local audio or video file")

            Divider().frame(height: 18)

            TextField("Paste a YouTube URL", text: $viewModel.youTubeURLString)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 220)
                .onSubmit(triggerImport)

            Button(action: triggerImport) {
                Label("Import", systemImage: "arrow.down.circle")
            }
            .disabled(viewModel.youTubeURLString.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isImporting)

            Spacer(minLength: 12)

            statusView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var statusView: some View {
        if viewModel.importStatus != .idle {
            HStack(spacing: 8) {
                if viewModel.isImporting {
                    ProgressView().controlSize(.small)
                }
                Text(viewModel.importStatus.label)
                    .font(.callout)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 320, alignment: .trailing)
        }
    }

    private var statusColor: Color {
        switch viewModel.importStatus {
        case .failed: return .red
        case .ready: return .secondary
        default: return .primary
        }
    }

    private func triggerImport() {
        viewModel.importYouTube()
    }
}
