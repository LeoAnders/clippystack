//
//  ClipboardRepositoryTests.swift
//  clippystackTests
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import XCTest
@testable import clippystack

final class ClipboardRepositoryTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testReloadHistoryAppliesLimitAndFavorites() async throws {
        let monitor = FakeMonitor()
        let persistence = FakePersistence(
            history: [
                ClipboardItem(content: "1"),
                ClipboardItem(content: "fav", isFavorite: true),
                ClipboardItem(content: "3")
            ],
            settings: AppSettings(historyLimit: 2)
        )
        let repo = ClipboardRepositoryImpl(
            monitor: monitor,
            persistence: persistence,
            copyService: FakeCopyService()
        )

        let expectation = expectation(description: "receive items")
        repo.itemsPublisher
            .sink { items in
                if !items.isEmpty { expectation.fulfill() }
            }
            .store(in: &cancellables)

        let items = try await repo.reloadHistory()
        waitForExpectations(timeout: 1)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.content, "fav")
    }

    func testIngestionDeduplicatesAndMovesToTop() async throws {
        let monitor = FakeMonitor()
        let persistence = FakePersistence(settings: AppSettings(historyLimit: 5))
        let repo = ClipboardRepositoryImpl(
            monitor: monitor,
            persistence: persistence,
            copyService: FakeCopyService()
        )

        repo.startMonitoring()

        let expectation = expectation(description: "dedup")
        expectation.expectedFulfillmentCount = 2

        repo.itemsPublisher
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        monitor.emit(ClipboardItem(content: "A"))
        monitor.emit(ClipboardItem(content: "A"))

        waitForExpectations(timeout: 1)
        let items = await repo.currentItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "A")
    }

    func testToggleFavoritePersistsAndReorders() async throws {
        let item = ClipboardItem(content: "A")
        let monitor = FakeMonitor()
        let persistence = FakePersistence(history: [item], settings: AppSettings(historyLimit: 3))
        let repo = ClipboardRepositoryImpl(
            monitor: monitor,
            persistence: persistence,
            copyService: FakeCopyService()
        )

        _ = try await repo.reloadHistory()
        let updated = try await repo.toggleFavorite(id: item.id)

        XCTAssertEqual(updated?.isFavorite, true)
        let savedHistory = await persistence.savedHistory.last
        XCTAssertEqual(savedHistory?.first?.isFavorite, true)
    }

    func testClearHistoryEmptiesAndPersists() async throws {
        let monitor = FakeMonitor()
        let persistence = FakePersistence(history: [ClipboardItem(content: "A")])
        let repo = ClipboardRepositoryImpl(
            monitor: monitor,
            persistence: persistence,
            copyService: FakeCopyService()
        )

        _ = try await repo.reloadHistory()
        try await repo.clearHistory()

        let items = await repo.currentItems()
        XCTAssertTrue(items.isEmpty)
        let saved = await persistence.savedHistory.last ?? []
        XCTAssertTrue(saved.isEmpty)
    }

    func testCopyDelegatesToCopyService() async throws {
        let monitor = FakeMonitor()
        let copy = FakeCopyService()
        let persistence = FakePersistence()
        let repo = ClipboardRepositoryImpl(
            monitor: monitor,
            persistence: persistence,
            copyService: copy
        )

        let item = ClipboardItem(content: "to copy")
        try await repo.copyToClipboard(item)

        let copied = await copy.copied.last
        XCTAssertEqual(copied?.content, "to copy")
    }
}

// MARK: - Test Doubles

private final class FakeMonitor: ClipboardMonitorType {
    private let subject = PassthroughSubject<ClipboardItem, Never>()
    private(set) var started = false

    var publisher: AnyPublisher<ClipboardItem, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        started = true
    }

    func emit(_ item: ClipboardItem) {
        subject.send(item)
    }
}

private actor FakePersistence: ClipboardPersistence, SettingsStore {
    var history: [ClipboardItem]
    var settings: AppSettings
    var savedHistory: [[ClipboardItem]] = []
    var savedSettings: [AppSettings] = []

    init(history: [ClipboardItem] = [], settings: AppSettings = AppSettings()) {
        self.history = history
        self.settings = settings
    }

    func loadHistory() async throws -> [ClipboardItem] {
        history
    }

    func saveHistory(_ items: [ClipboardItem], settings: AppSettings) async throws {
        savedHistory.append(items)
        history = items
        self.settings = settings
    }

    func load() async throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) async throws {
        savedSettings.append(settings)
        self.settings = settings
    }
}

private actor FakeCopyService: CopyService {
    var copied: [ClipboardItem] = []

    func copy(_ item: ClipboardItem) async throws {
        copied.append(item)
    }
}
