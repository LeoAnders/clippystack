//
//  ClipboardMonitorTests.swift
//  clippystackTests
//
//  Created by Leonardo Anders on 01/12/25.
//

import AppKit
import Combine
import XCTest
@testable import clippystack

final class ClipboardMonitorTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testPublishesNewClipboardItemOnChange() {
        let pasteboard = FakePasteboardAdapter()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 5)
        let expectation = expectation(description: "emit clipboard item")

        var received: ClipboardItem?
        monitor.publisher
            .sink { item in
                received = item
                expectation.fulfill()
            }
            .store(in: &cancellables)

        pasteboard.push("Hello world")
        monitor.pollPasteboard()

        waitForExpectations(timeout: 1)

        XCTAssertEqual(received?.content, "Hello world")
        XCTAssertEqual(received?.type, .text)
    }

    func testDeduplicatesConsecutiveValues() {
        let pasteboard = FakePasteboardAdapter()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 5)
        let expectation = expectation(description: "emit only once")
        expectation.expectedFulfillmentCount = 1

        var emittedCount = 0
        monitor.publisher
            .sink { _ in
                emittedCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)

        pasteboard.push("same")
        monitor.pollPasteboard()

        pasteboard.push("same")
        monitor.pollPasteboard()

        waitForExpectations(timeout: 1)
        XCTAssertEqual(emittedCount, 1, "Valores consecutivos idênticos não devem gerar novo item.")
    }

    func testIgnoresEmptyOrWhitespaceOnlyContent() {
        let pasteboard = FakePasteboardAdapter()
        let monitor = ClipboardMonitor(pasteboard: pasteboard, pollInterval: 5)

        var emittedCount = 0
        monitor.publisher
            .sink { _ in emittedCount += 1 }
            .store(in: &cancellables)

        pasteboard.push("   ")
        monitor.pollPasteboard()

        pasteboard.push("  spaced value  ")
        monitor.pollPasteboard()

        XCTAssertEqual(emittedCount, 1)
    }
}

private final class FakePasteboardAdapter: PasteboardAdapter {
    var changeCount: Int = 0
    private(set) var currentString: String?

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        currentString
    }

    func push(_ value: String?) {
        changeCount += 1
        currentString = value
    }
}
