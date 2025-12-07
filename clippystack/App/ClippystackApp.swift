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
            ?? { fatalError("Could not initialize JSONPersistence") }()

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
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Quick Actions") {
                Button("Focus Search", action: {}) // handled in view via keyboard shortcut
                    .keyboardShortcut("f", modifiers: [.command])

                Divider()

                Button("Next Item") { viewModel.selectNext() }
                    .keyboardShortcut("j", modifiers: [.command])
                Button("Previous Item") { viewModel.selectPrevious() }
                    .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button("Toggle Favorite") { viewModel.toggleFavoriteSelected() }
                    .keyboardShortcut("d", modifiers: [.command])

                Button("Copy") { viewModel.copySelected(closeAfterPaste: false) }
                    .keyboardShortcut("c", modifiers: [.command])
                Button("Copy + Close") { viewModel.copySelected(closeAfterPaste: true) }
                    .keyboardShortcut(.return, modifiers: [.command])

                Divider()
            }
        }
    }
}
