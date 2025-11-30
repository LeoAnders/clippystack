//
//  ModelSerializationTests.swift
//  clippystackTests
//
//  Created by Leonardo Anders on 30/11/25.
//

import XCTest
@testable import clippystack

final class ModelSerializationTests: XCTestCase {
    func testClipboardItemCodableRoundTrip() throws {
        let item = ClipboardItem(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            content: "Sample content",
            type: .text,
            isFavorite: true,
            metadata: ClipboardMetadata(
                sourceAppName: "Notes",
                sourceBundleIdentifier: "com.apple.Notes",
                extra: ["format": "plain"]
            )
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded, item)
        XCTAssertEqual(decoded.type, .text)
        XCTAssertTrue(decoded.isFavorite)
        XCTAssertEqual(decoded.metadata.sourceAppName, "Notes")
    }

    func testAppSettingsEnforcesPositiveHistoryLimit() throws {
        let settings = AppSettings(
            historyLimit: 0,
            closeAfterPaste: true,
            launchAtLogin: false,
            showPreview: true,
            globalShortcut: KeyboardShortcutDescriptor(key: "c", modifiers: [.command, .option])
        )

        XCTAssertEqual(settings.historyLimit, 1, "historyLimit deve ser normalizado para > 0")
        XCTAssertEqual(settings.globalShortcut.key, "c")
        XCTAssertEqual(settings.globalShortcut.modifiers, [.command, .option])
    }

    func testKeyboardShortcutDescriptorCodableRoundTrip() throws {
        let descriptor = KeyboardShortcutDescriptor(key: "v", modifiers: [.command, .shift])

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(KeyboardShortcutDescriptor.self, from: data)

        XCTAssertEqual(decoded, descriptor)
    }
}
