//
//  ViewModelTests.swift
//  clippystackTests
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import XCTest
@testable import clippystack

@MainActor
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

    func testFavoritesScopeShowsOnlyFavorites() {
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

        vm.filterScope = .favorites

        XCTAssertEqual(vm.displayedItems.count, 1)
        XCTAssertEqual(vm.displayedItems.first?.content, "B")
    }

    func testScopeFiltersByTypeAndKeepsSelectionNavigation() async throws {
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
            ClipboardItem(content: "Text A", type: .text),
            ClipboardItem(content: "Image B", type: .image),
            ClipboardItem(content: "Link C", type: .link),
            ClipboardItem(content: "Text D", type: .text)
        ])

        try await Task.sleep(nanoseconds: 10_000_000)

        vm.filterScope = .text
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(vm.displayedItems.map(\.content), ["Text A", "Text D"])
        XCTAssertEqual(vm.selectedItem?.content, "Text A")

        vm.selectNext()
        XCTAssertEqual(vm.selectedItem?.content, "Text D")
        vm.selectPrevious()
        XCTAssertEqual(vm.selectedItem?.content, "Text A")

        vm.filterScope = .link
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(vm.displayedItems.map(\.content), ["Link C"])
        vm.selectNext()
        XCTAssertEqual(vm.selectedItem?.content, "Link C")
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

    func testShowFooterStatusAutoHides() async throws {
        let repo = FakeClipboardRepository()
        let settingsStore = FakeSettingsStore()
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        vm.showFooterStatus(FooterStatus(message: "Hello", kind: .success), autoHideAfter: 0.05)
        XCTAssertEqual(vm.footerStatus?.message, "Hello")

        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertNil(vm.footerStatus)
    }

    func testDeletePublishesSuccessStatus() async throws {
        let item = ClipboardItem(content: "Remove me")
        let repo = FakeClipboardRepository(items: [item])
        let settingsStore = FakeSettingsStore()
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        repo.itemsSubject.send(repo.items)
        vm.delete(item)

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.footerStatus?.kind, .success)
        XCTAssertEqual(vm.footerStatus?.message, "Deleted entry")
    }

    func testClearHistoryErrorShowsFooterStatus() async throws {
        let repo = FakeClipboardRepository(items: [ClipboardItem(content: "A")])
        let settingsStore = FakeSettingsStore()
        repo.clearError = StubError(message: "boom")

        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        vm.clearHistoryRequest()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(vm.footerStatus?.kind, .error)
        XCTAssertEqual(vm.footerStatus?.message, "boom")
    }

    func testSelectionNavigationAndFavoriteToggle() async throws {
        let repo = FakeClipboardRepository(items: [
            ClipboardItem(content: "First"),
            ClipboardItem(content: "Second"),
            ClipboardItem(content: "Third")
        ])
        let settingsStore = FakeSettingsStore()
        let vm = MainWindowViewModel(
            repository: repo,
            settingsStore: settingsStore,
            initialSettings: AppSettings(),
            debounceInterval: .milliseconds(0),
            scheduler: .main
        )

        repo.itemsSubject.send(repo.items)
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(vm.displayedItems.count, 3)
        XCTAssertEqual(vm.selectedItem?.content, "First")

        vm.selectNext()
        XCTAssertEqual(vm.selectedItem?.content, "Second")

        vm.selectPrevious()
        XCTAssertEqual(vm.selectedItem?.content, "First")

        vm.selectByIndex(2)
        XCTAssertEqual(vm.selectedItem?.content, "Third")

        vm.toggleFavoriteSelected()
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertTrue(vm.selectedItem?.isFavorite ?? false)
    }

    @MainActor
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
    var clearError: Error?
    var deleteError: Error?
    var toggleFavoriteError: Error?
    var copyError: Error?

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
        if let toggleFavoriteError {
            throw toggleFavoriteError
        }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        var item = items[index]
        item.isFavorite.toggle()
        items[index] = item
        return item
    }

    func delete(id: UUID) async throws {
        if let deleteError {
            throw deleteError
        }
        items.removeAll { $0.id == id }
    }

    func clearHistory() async throws {
        if let clearError {
            throw clearError
        }
        items.removeAll()
    }

    func clearNonFavorites() async throws {
        items = items.filter { $0.isFavorite }
    }

    func copyToClipboard(_ item: ClipboardItem) async throws {
        if let copyError {
            throw copyError
        }
        copiedItems.append(item)
    }
}

private struct StubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
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
