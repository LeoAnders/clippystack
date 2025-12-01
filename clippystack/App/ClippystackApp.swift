//
//  ClippystackApp.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import SwiftUI

@main
@MainActor
struct ClippystackApp: App {
    @StateObject private var viewModel: MainWindowViewModel

    init() {
        let persistence = (try? JSONPersistence())
            ?? (try? JSONPersistence(baseDirectory: FileManager.default.temporaryDirectory))
            ?? { fatalError("Não foi possível inicializar JSONPersistence") }()

        let repository = ClipboardRepositoryImpl(
            monitor: ClipboardMonitor(),
            persistence: persistence,
            copyService: SystemCopyService()
        )

        _viewModel = StateObject(
            wrappedValue: MainWindowViewModel(
                repository: repository,
                settingsStore: persistence
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(viewModel: viewModel)
        }
    }
}
