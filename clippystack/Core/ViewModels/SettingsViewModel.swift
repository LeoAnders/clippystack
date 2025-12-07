//
//  SettingsViewModel.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import Foundation

protocol LaunchAtLoginManaging: Sendable {
    func isEnabled() async -> Bool
    func setEnabled(_ enabled: Bool) async throws
}

/// Fallback that does not change login; useful for tests or environments without a real implementation.
struct NoopLaunchAtLoginManager: LaunchAtLoginManaging {
    func isEnabled() async -> Bool { false }
    func setEnabled(_ enabled: Bool) async throws { _ = enabled }
}

/// ViewModel for the settings screen.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var historyLimit: Int = AppSettings().historyLimit
    @Published var closeAfterPaste: Bool = AppSettings().closeAfterPaste
    @Published var launchAtLogin: Bool = AppSettings().launchAtLogin
    @Published var showPreview: Bool = AppSettings().showPreview
    @Published var globalShortcut: KeyboardShortcutDescriptor = AppSettings().globalShortcut

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?

    private let settingsStore: SettingsStore
    private let launchManager: LaunchAtLoginManaging

    init(
        settingsStore: SettingsStore,
        launchManager: LaunchAtLoginManaging = NoopLaunchAtLoginManager()
    ) {
        self.settingsStore = settingsStore
        self.launchManager = launchManager
    }

    func load() {
        Task {
            await setLoading(true)
            defer { Task { await self.setLoading(false) } }
            do {
                let settings = try await settingsStore.load()
                historyLimit = settings.historyLimit
                closeAfterPaste = settings.closeAfterPaste
                showPreview = settings.showPreview
                globalShortcut = settings.globalShortcut

                let launch = await launchManager.isEnabled()
                launchAtLogin = launch
            } catch {
                lastError = "Failed to load settings: \(error)"
            }
        }
    }

    func save() {
        Task {
            await setLoading(true)
            defer { Task { await self.setLoading(false) } }
            do {
                let settings = AppSettings(
                    historyLimit: historyLimit,
                    closeAfterPaste: closeAfterPaste,
                    launchAtLogin: launchAtLogin,
                    showPreview: showPreview,
                    globalShortcut: globalShortcut
                )
                try await settingsStore.save(settings)
                try await launchManager.setEnabled(launchAtLogin)
                lastError = nil
            } catch {
                lastError = "Failed to save settings: \(error)"
            }
        }
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) async {
        isLoading = loading
    }
}
