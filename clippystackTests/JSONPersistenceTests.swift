//
//  JSONPersistenceTests.swift
//  clippystackTests
//
//  Created by Leonardo Anders on 01/12/25.
//

import XCTest
@testable import clippystack

final class JSONPersistenceTests: XCTestCase {
    private var fileManager: FileManager!

    override func setUp() {
        super.setUp()
        fileManager = .default
    }

    func testSaveAndLoadHistoryRoundTrip() async throws {
        let (baseURL, persistence) = try makePersistence()
        addTeardownBlock { try? self.fileManager.removeItem(at: baseURL) }

        let items = [
            ClipboardItem(content: "First"),
            ClipboardItem(content: "Second")
        ]

        try await persistence.saveHistory(items, settings: AppSettings(historyLimit: 10))
        let loaded = try await persistence.loadHistory()

        XCTAssertEqual(loaded.map(\.content), ["First", "Second"])
    }

    func testHistoryTruncationKeepsFavoritesOnTop() async throws {
        let (baseURL, persistence) = try makePersistence()
        addTeardownBlock { try? self.fileManager.removeItem(at: baseURL) }

        let items = [
            ClipboardItem(content: "oldest"),
            ClipboardItem(content: "fav", isFavorite: true),
            ClipboardItem(content: "newest")
        ]

        try await persistence.saveHistory(items, settings: AppSettings(historyLimit: 2))
        let loaded = try await persistence.loadHistory()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.content, "fav", "Favoritos devem ser priorizados ao truncar.")
    }

    func testSaveAndLoadSettingsRoundTrip() async throws {
        let (baseURL, persistence) = try makePersistence()
        addTeardownBlock { try? self.fileManager.removeItem(at: baseURL) }

        let settings = AppSettings(
            historyLimit: 5,
            closeAfterPaste: true,
            launchAtLogin: true,
            showPreview: false,
            globalShortcut: KeyboardShortcutDescriptor(key: "c", modifiers: [.command, .option])
        )

        try await persistence.save(settings)
        let loaded = try await persistence.load()

        XCTAssertEqual(loaded, settings)
    }

    func testMissingFilesReturnDefaults() async throws {
        let (baseURL, persistence) = try makePersistence()
        addTeardownBlock { try? self.fileManager.removeItem(at: baseURL) }

        let history = try await persistence.loadHistory()
        let settings = try await persistence.load()

        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(settings, AppSettings())
    }

    func testCorruptedFilesFallbackGracefully() async throws {
        let (baseURL, persistence) = try makePersistence()
        addTeardownBlock { try? self.fileManager.removeItem(at: baseURL) }

        let historyURL = baseURL.appendingPathComponent("history.json")
        let settingsURL = baseURL.appendingPathComponent("settings.json")
        try "not-json".data(using: .utf8)?.write(to: historyURL)
        try "also-not-json".data(using: .utf8)?.write(to: settingsURL)

        let history = try await persistence.loadHistory()
        let settings = try await persistence.load()

        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(settings, AppSettings())
    }

    // MARK: - Helpers

    private func makePersistence() throws -> (URL, JSONPersistence) {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let persistence = try JSONPersistence(baseDirectory: tempDir, fileManager: fileManager)
        return (tempDir, persistence)
    }
}
