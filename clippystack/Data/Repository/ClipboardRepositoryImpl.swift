//
//  ClipboardRepositoryImpl.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import AppKit
import Combine
import Foundation

/// Copy service that writes back to `NSPasteboard`.
protocol CopyService {
    func copy(_ item: ClipboardItem) async throws
}

/// Default implementation that writes strings to the system pasteboard.
final class SystemCopyService: CopyService {
    func copy(_ item: ClipboardItem) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }
}

/// Allows monitor mocks in tests.
protocol ClipboardMonitorType {
    var publisher: AnyPublisher<ClipboardItem, Never> { get }
    func start()
}

extension ClipboardMonitor: ClipboardMonitorType {}

/// Stores and manages history in a thread-safe manner.
actor ClipboardHistoryStore {
    private var items: [ClipboardItem] = []

    func all() -> [ClipboardItem] {
        items
    }

    func setInitial(_ newItems: [ClipboardItem], limit: Int) -> [ClipboardItem] {
        items = Self.applyLimit(newItems, limit: limit)
        return items
    }

    func insert(_ item: ClipboardItem, limit: Int) -> [ClipboardItem] {
        if let existingIndex = items.firstIndex(where: { $0.content == item.content }) {
            let existing = items.remove(at: existingIndex)
            let merged = ClipboardItem(
                id: existing.id,
                capturedAt: item.capturedAt,
                content: item.content,
                type: item.type,
                isFavorite: existing.isFavorite || item.isFavorite,
                metadata: item.metadata
            )
            items.insert(merged, at: 0)
        } else {
            items.insert(item, at: 0)
        }

        items = Self.applyLimit(items, limit: limit)
        return items
    }

    func toggleFavorite(id: UUID, limit: Int) -> (ClipboardItem?, [ClipboardItem]) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return (nil, items)
        }

        let current = items[index]
        let toggled = ClipboardItem(
            id: current.id,
            capturedAt: current.capturedAt,
            content: current.content,
            type: current.type,
            isFavorite: !current.isFavorite,
            metadata: current.metadata
        )

        items[index] = toggled
        items = Self.applyLimit(items, limit: limit)
        return (toggled, items)
    }

    func clear() -> [ClipboardItem] {
        items.removeAll()
        return items
    }

    private static func applyLimit(_ items: [ClipboardItem], limit: Int) -> [ClipboardItem] {
        guard limit > 0 else { return [] }
        let favorites = items.filter { $0.isFavorite }
        let rest = items.filter { !$0.isFavorite }
        return Array((favorites + rest).prefix(limit))
    }
}

/// Concrete `ClipboardRepository` integrating monitor, persistence, and copy services.
final class ClipboardRepositoryImpl: ClipboardRepository {
    private let monitor: ClipboardMonitorType
    private let persistence: (ClipboardPersistence & SettingsStore)
    private let copyService: CopyService
    private let historyStore: ClipboardHistoryStore
    private var settings: AppSettings
    private var cancellables: Set<AnyCancellable> = []
    private let subject = CurrentValueSubject<[ClipboardItem], Never>([])

    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        monitor: ClipboardMonitorType = ClipboardMonitor(),
        persistence: (ClipboardPersistence & SettingsStore) = try! JSONPersistence(),
        copyService: CopyService = SystemCopyService(),
        historyStore: ClipboardHistoryStore = ClipboardHistoryStore(),
        initialSettings: AppSettings = .init()
    ) {
        self.monitor = monitor
        self.persistence = persistence
        self.copyService = copyService
        self.historyStore = historyStore
        self.settings = initialSettings
    }

    func startMonitoring() {
        guard cancellables.isEmpty else { return }

        monitor.publisher
            .sink { [weak self] item in
                guard let self else { return }
                Task { await self.handleNew(item) }
            }
            .store(in: &cancellables)

        monitor.start()
    }

    func currentItems() async -> [ClipboardItem] {
        await historyStore.all()
    }

    func reloadHistory() async throws -> [ClipboardItem] {
        let loadedSettings = try await persistence.load()
        settings = loadedSettings

        let history = try await persistence.loadHistory()
        let normalized = await historyStore.setInitial(history, limit: settings.historyLimit)
        subject.send(normalized)
        return normalized
    }

    func toggleFavorite(id: UUID) async throws -> ClipboardItem? {
        let (updated, items) = await historyStore.toggleFavorite(id: id, limit: settings.historyLimit)
        subject.send(items)
        try await persistence.saveHistory(items, settings: settings)
        return updated
    }

    func clearHistory() async throws {
        let cleared = await historyStore.clear()
        subject.send(cleared)
        try await persistence.saveHistory(cleared, settings: settings)
    }

    func copyToClipboard(_ item: ClipboardItem) async throws {
        try await copyService.copy(item)
    }

    // MARK: - Private

    private func handleNew(_ item: ClipboardItem) async {
        let updated = await historyStore.insert(item, limit: settings.historyLimit)
        subject.send(updated)
        try? await persistence.saveHistory(updated, settings: settings)
    }
}

extension ClipboardRepositoryImpl: @unchecked Sendable {}
