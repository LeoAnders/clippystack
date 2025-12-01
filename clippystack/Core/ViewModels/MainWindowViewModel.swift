//
//  MainWindowViewModel.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import Foundation

/// Controla a lista exibida, seleção e ações da janela principal.
@MainActor
final class MainWindowViewModel: ObservableObject {
    @Published var displayedItems: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    @Published var favoriteFilter: Bool = false
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

    /// Inicia monitoramento e carrega histórico + settings.
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

    func copySelectedAndCloseIfNeeded() {
        guard let selected = selectedItem else { return }
        Task {
            try? await repository.copyToClipboard(selected)
            if settings.closeAfterPaste {
                onCloseRequested?()
            }
        }
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

        $favoriteFilter
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

        if favoriteFilter {
            filtered = filtered.filter { $0.isFavorite }
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
