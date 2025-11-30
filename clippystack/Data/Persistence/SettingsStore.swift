//
//  SettingsStore.swift
//  clippystack
//
//  Created by Leonardo Anders on 30/11/25.
//

import Foundation

/// Armazena e recupera configurações do aplicativo.
protocol SettingsStore: Sendable {
    /// Carrega `AppSettings`, aplicando defaults quando necessário.
    func load() async throws -> AppSettings

    /// Persiste as configurações fornecidas.
    func save(_ settings: AppSettings) async throws
}
