//
//  ShedApp.swift
//  Shed
//

import SwiftUI

@main
struct ShedApp: App {
    @State private var viewModel = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .frame(minWidth: 920, minHeight: 580)
        }
        .windowToolbarStyle(.unified)
    }
}
