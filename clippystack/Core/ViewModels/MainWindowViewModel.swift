//
//  MainWindowViewModel.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import Foundation

enum ClipboardFilterScope: String, CaseIterable, Identifiable {
    case all
    case favorites
    case text
    case images
    case links

    var id: String { rawValue }
}

@MainActor
final class MainWindowViewModel: ObservableObject {
    @Published var displayedItems: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    @Published var filterScope: ClipboardFilterScope = .all
    @Published var selectedItem: ClipboardItem?
    @Published var isPreviewVisible: Bool = true

    var onCloseRequested: (() -> Void)?

    private let repository: ClipboardRepository
    private let settingsStore: SettingsStore
    private var settings: AppSettings
    private let debounceInterval: DispatchQueue.SchedulerTimeType.Stride
    private let scheduler: DispatchQueue
    private var baseItems: [ClipboardItem] = []
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: ClipboardRepository,
        settingsStore: SettingsStore,
        initialSettings: AppSettings = .init(),
        debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(250),
        scheduler: DispatchQueue = .main
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.settings = initialSettings
        self.debounceInterval = debounceInterval
        self.scheduler = scheduler
        self.isPreviewVisible = initialSettings.showPreview
        bind()
    }

    /// Starts monitoring and loads history + settings.
    func onAppear() {
        Task {
            await self.loadSettingsAndHistory()
        }
        repository.startMonitoring()
    }

    func toggleFavorite(_ item: ClipboardItem) {
        Task {
            _ = try? await repository.toggleFavorite(id: item.id)
        }
    }

    func toggleFavoriteSelected() {
        guard let selectedItem else { return }
        toggleFavorite(selectedItem)
    }

    func copy(_ item: ClipboardItem, closeAfterPaste: Bool) {
        Task {
            try? await repository.copyToClipboard(item)
            if closeAfterPaste, settings.closeAfterPaste {
                onCloseRequested?()
            }
        }
    }

    func copySelected(closeAfterPaste: Bool) {
        guard let selectedItem else { return }
        copy(selectedItem, closeAfterPaste: closeAfterPaste)
    }

    func copySelectedAndCloseIfNeeded() {
        copySelected(closeAfterPaste: true)
    }

    func selectNext() {
        guard !displayedItems.isEmpty else { return }
        let currentIndex = displayedItems.firstIndex(where: { $0.id == selectedItem?.id }) ?? -1
        let nextIndex = min(displayedItems.count - 1, currentIndex + 1)
        selectedItem = displayedItems[nextIndex]
    }

    func selectPrevious() {
        guard !displayedItems.isEmpty else { return }
        let currentIndex = displayedItems.firstIndex(where: { $0.id == selectedItem?.id }) ?? displayedItems.count
        let prevIndex = max(0, currentIndex - 1)
        selectedItem = displayedItems[prevIndex]
    }

    func selectByIndex(_ index: Int) {
        guard displayedItems.indices.contains(index) else { return }
        selectedItem = displayedItems[index]
    }

    func clearHistoryRequest() {
        Task {
            try? await repository.clearHistory()
        }
    }

    func togglePreview() {
        isPreviewVisible.toggle()
        settings.showPreview = isPreviewVisible
        Task {
            try? await settingsStore.save(settings)
        }
    }

    // MARK: - Private

    private func bind() {
        repository.itemsPublisher
            .receive(on: scheduler)
            .sink { [weak self] items in
                self?.baseItems = items
                self?.applyFilters()
            }
            .store(in: &cancellables)

        $searchQuery
            .debounce(for: debounceInterval, scheduler: scheduler)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)

        $filterScope
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    private func loadSettingsAndHistory() async {
        if let loadedSettings = try? await settingsStore.load() {
            settings = loadedSettings
            isPreviewVisible = loadedSettings.showPreview
        }

        if let items = try? await repository.reloadHistory() {
            baseItems = items
            applyFilters()
        }
    }

    private func applyFilters() {
        var filtered = baseItems

        switch filterScope {
        case .favorites:
            filtered = filtered.filter { $0.isFavorite }
        case .text:
            filtered = filtered.filter { $0.type == .text }
        case .images:
            filtered = filtered.filter { $0.type == .image }
        case .links:
            filtered = filtered.filter { $0.type == .link }
        case .all:
            break
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            filtered = filtered.filter {
                $0.content.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        displayedItems = filtered
        reconcileSelection(with: filtered)
    }

    private func reconcileSelection(with items: [ClipboardItem]) {
        if let selected = selectedItem, items.contains(where: { $0.id == selected.id }) {
            return
        }
        selectedItem = items.first
    }
}
