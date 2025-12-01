//
//  ViewModelTests.swift
//  clippystackTests
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import XCTest
@testable import clippystack

final class ViewModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testSearchFilteringWithDebounce() async throws {
        let repo = FakeClipboardRepository()
        let settingsStore = FakeSettingsStore()
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(10),
            scheduler: .main
        )

        repo.itemsSubject.send([
            ClipboardItem(content: "Hello"),
            ClipboardItem(content: "World"),
            ClipboardItem(content: "Test")
        ])

        let expectation = expectation(description: "filtered")
        vm.$displayedItems
            .dropFirst()
            .sink { items in
                if items.count == 1, items.first?.content == "World" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        vm.searchQuery = "wo"

        waitForExpectations(timeout: 1)
    }

    func testFavoriteFilterShowsOnlyFavorites() {
        let repo = FakeClipboardRepository()
        let settingsStore = FakeSettingsStore()
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        repo.itemsSubject.send([
            ClipboardItem(content: "A", isFavorite: false),
            ClipboardItem(content: "B", isFavorite: true)
        ])

        vm.favoriteFilter = true

        XCTAssertEqual(vm.displayedItems.count, 1)
        XCTAssertEqual(vm.displayedItems.first?.content, "B")
    }

    func testCopySelectedTriggersCloseWhenEnabled() async throws {
        let repo = FakeClipboardRepository()
        let settingsStore = FakeSettingsStore(saved: AppSettings(closeAfterPaste: true))
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(closeAfterPaste: true),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        let item = ClipboardItem(content: "copy me")
        vm.selectedItem = item

        var closed = false
        vm.onCloseRequested = { closed = true }

        vm.copySelectedAndCloseIfNeeded()

        // Allow async tasks to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(await repo.copiedItems.last, item)
        XCTAssertTrue(closed)
    }

    func testClearHistoryDelegatesToRepository() async throws {
        let repo = FakeClipboardRepository(items: [ClipboardItem(content: "A")])
        let settingsStore = FakeSettingsStore()
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        repo.itemsSubject.send(repo.items)
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertFalse(vm.displayedItems.isEmpty)

        vm.clearHistoryRequest()
        try await Task.sleep(nanoseconds: 50_000_000)

        let current = await repo.currentItems()
        XCTAssertTrue(current.isEmpty)
    }

    func testSettingsViewModelLoadAndSave() async throws {
        let settings = AppSettings(
            historyLimit: 50,
            closeAfterPaste: true,
            launchAtLogin: false,
            showPreview: true,
            globalShortcut: KeyboardShortcutDescriptor(key: "v", modifiers: [.command, .shift])
        )
        let store = FakeSettingsStore(saved: settings)
        let launch = FakeLaunchManager()
        launch.enabled = true

        let vm = SettingsViewModel(settingsStore: store, launchManager: launch)
        vm.load()

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.historyLimit, 50)
        XCTAssertTrue(vm.closeAfterPaste)
        XCTAssertTrue(vm.launchAtLogin)
        XCTAssertTrue(vm.showPreview)

        vm.historyLimit = 10
        vm.launchAtLogin = false
        vm.save()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(await store.savedSettings.last?.historyLimit, 10)
        XCTAssertFalse(await launch.lastSet ?? true)
    }
}

// MARK: - Fakes

private final class FakeClipboardRepository: ClipboardRepository, @unchecked Sendable {
    let itemsSubject: CurrentValueSubject<[ClipboardItem], Never>
    private(set) var items: [ClipboardItem] {
        didSet { itemsSubject.send(items) }
    }
    private(set) var copiedItems: [ClipboardItem] = []
    private(set) var started = false

    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    init(items: [ClipboardItem] = []) {
        self.items = items
        self.itemsSubject = CurrentValueSubject(items)
    }

    func startMonitoring() {
        started = true
    }

    func currentItems() async -> [ClipboardItem] {
        items
    }

    func reloadHistory() async throws -> [ClipboardItem] {
        itemsSubject.send(items)
        return items
    }

    func toggleFavorite(id: UUID) async throws -> ClipboardItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        var item = items[index]
        item.isFavorite.toggle()
        items[index] = item
        return item
    }

    func clearHistory() async throws {
        items.removeAll()
    }

    func copyToClipboard(_ item: ClipboardItem) async throws {
        copiedItems.append(item)
    }
}

private actor FakeSettingsStore: SettingsStore {
    var saved: AppSettings
    var savedSettings: [AppSettings] = []

    init(saved: AppSettings = AppSettings()) {
        self.saved = saved
    }

    func load() async throws -> AppSettings {
        saved
    }

    func save(_ settings: AppSettings) async throws {
        saved = settings
        savedSettings.append(settings)
    }
}

private actor FakeLaunchManager: LaunchAtLoginManaging {
    var enabled: Bool = false
    var lastSet: Bool?

    func isEnabled() async -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) async throws {
        self.enabled = enabled
        self.lastSet = enabled
    }
}
