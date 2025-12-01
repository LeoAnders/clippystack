//
//  JSONPersistence.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import Foundation

/// Persistência de histórico de clipboard.
protocol ClipboardPersistence: Sendable {
    func loadHistory() async throws -> [ClipboardItem]
    func saveHistory(_ items: [ClipboardItem], settings: AppSettings) async throws
}

/// Persistência local em arquivos JSON para histórico e configurações.
final class JSONPersistence: ClipboardPersistence, SettingsStore {
    private let fileManager: FileManager
    private let historyURL: URL
    private let settingsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        let baseURL = try baseDirectory ?? Self.makeDefaultBaseDirectory(fileManager: fileManager)
        self.historyURL = baseURL.appendingPathComponent("history.json", isDirectory: false)
        self.settingsURL = baseURL.appendingPathComponent("settings.json", isDirectory: false)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - ClipboardPersistence

    func loadHistory() async throws -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: historyURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyURL)
            guard !data.isEmpty else { return [] }
            return try decoder.decode([ClipboardItem].self, from: data)
        } catch {
            // Arquivo corrompido ou formato inesperado: retornar vazio.
            return []
        }
    }

    func saveHistory(_ items: [ClipboardItem], settings: AppSettings) async throws {
        let limited = Self.truncateHistory(items, limit: settings.historyLimit)
        let data = try encoder.encode(limited)
        try writeAtomically(data, to: historyURL)
    }

    // MARK: - SettingsStore

    func load() async throws -> AppSettings {
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return AppSettings()
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            guard !data.isEmpty else { return AppSettings() }
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            // Arquivo corrompido: retornar defaults.
            return AppSettings()
        }
    }

    func save(_ settings: AppSettings) async throws {
        let data = try encoder.encode(settings)
        try writeAtomically(data, to: settingsURL)
    }

    // MARK: - Helpers

    private func writeAtomically(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private static func truncateHistory(_ items: [ClipboardItem], limit: Int) -> [ClipboardItem] {
        guard limit > 0 else { return [] }
        let favorites = items.filter { $0.isFavorite }
        let nonFavorites = items.filter { !$0.isFavorite }
        let prioritized = favorites + nonFavorites
        return Array(prioritized.prefix(limit))
    }

    private static func makeDefaultBaseDirectory(fileManager: FileManager) throws -> URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "clippystack"
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let baseURL = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        return baseURL
    }
}
