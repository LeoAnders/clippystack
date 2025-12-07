//
//  SettingsStore.swift
//  clippystack
//
//  Created by Leonardo Anders on 30/11/25.
//

import Foundation

/// Stores and retrieves app settings.
protocol SettingsStore: Sendable {
    /// Loads `AppSettings`, applying defaults when necessary.
    func load() async throws -> AppSettings

    /// Persists the provided settings.
    func save(_ settings: AppSettings) async throws
}
