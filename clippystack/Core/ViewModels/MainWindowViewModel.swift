//
//  MainWindowViewModel.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import Combine
import Foundation
#if canImport(AppKit)
import AppKit
#endif

enum ClipboardFilterScope: String, CaseIterable, Identifiable {
    case all
    case favorites
    case text
    case images
    case links

    var id: String { rawValue }
}

struct FooterStatus: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case success
        case warning
        case error
    }

    let id = UUID()
    let message: String
    let kind: Kind
    let timestamp: Date = Date()
}

@MainActor
final class MainWindowViewModel: ObservableObject {
    @Published var displayedItems: [ClipboardItem] = []
    @Published var searchQuery: String = ""
    @Published var filterScope: ClipboardFilterScope = .all
    @Published var selectedItem: ClipboardItem?
    @Published var isPreviewVisible: Bool = true
    @Published var footerStatus: FooterStatus?
    #if canImport(AppKit)
    @Published var pasteTargetAppName: String = "App"
    @Published var pasteTargetAppIcon: NSImage?
    #endif

    var onCloseRequested: (() -> Void)?

    private let repository: ClipboardRepository
    private let settingsStore: SettingsStore
    private var settings: AppSettings
    private let debounceInterval: DispatchQueue.SchedulerTimeType.Stride
    private let scheduler: DispatchQueue
    private var baseItems: [ClipboardItem] = []
    private var cancellables: Set<AnyCancellable> = []
    #if canImport(AppKit)
    private var lastExternalApp: NSRunningApplication?
    private var workspaceObserver: Any?
    #endif

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
        #if canImport(AppKit)
        startTrackingFrontmostApplication()
        #endif
    }

    var actionMenuItems: [ActionMenuItem] {
        let hasSelection = selectedItem != nil
        let isFavorite = selectedItem?.isFavorite ?? false
        let hasHistory = !displayedItems.isEmpty

        return [
            ActionMenuItem(
                id: .pasteToTargetApp,
                title: "Paste to \(pasteTargetAppName)",
                icon: "arrow.turn.down.left",
                appIcon: pasteTargetAppIcon,
                shortcutKeys: ["↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { [weak self] in self?.paste() }
            ),
            ActionMenuItem(
                id: .copyToClipboard,
                title: "Copy to Clipboard",
                icon: "doc.on.doc",
                appIcon: nil,
                shortcutKeys: ["⌘", "C"],
                role: .normal,
                isEnabled: hasSelection,
                action: { [weak self] in self?.copySelected(closeAfterPaste: false) }
            ),
            ActionMenuItem(
                id: .pasteKeepOpen,
                title: "Paste and Keep Window Open",
                icon: "arrow.triangle.2.circlepath",
                appIcon: pasteTargetAppIcon,
                shortcutKeys: ["⌃", "⇧", "↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { [weak self] in self?.pasteKeepOpen() }
            ),
            ActionMenuItem(
                id: .pasteAsPlainText,
                title: "Paste as Plain Text",
                icon: "text.alignleft",
                appIcon: nil,
                shortcutKeys: ["⌥", "⇧", "↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { [weak self] in self?.pasteAsPlainText() }
            ),
            ActionMenuItem(
                id: .toggleFavorite,
                title: isFavorite ? "Remove Favorite" : "Add Favorite",
                icon: isFavorite ? "star.slash" : "star",
                appIcon: nil,
                shortcutKeys: ["⌘", "D"],
                role: .normal,
                isEnabled: hasSelection,
                action: { [weak self] in self?.toggleFavoriteSelected() }
            ),
            ActionMenuItem(
                id: .deleteItem,
                title: "Delete Item",
                icon: "trash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⌫"],
                role: .destructive,
                isEnabled: hasSelection,
                action: { [weak self] in self?.deleteSelected() }
            ),
            ActionMenuItem(
                id: .clearAllHistory,
                title: "Clear All History",
                icon: "trash.slash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⇧", "⌫"],
                role: .destructive,
                isEnabled: hasHistory,
                action: { [weak self] in self?.clearHistoryRequest() }
            ),
            ActionMenuItem(
                id: .clearNonFavorites,
                title: "Clear Non-Favorites",
                icon: "star.slash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⌥", "⌫"],
                role: .destructive,
                isEnabled: hasHistory,
                action: { [weak self] in self?.clearNonFavorites() }
            )
        ]
    }

    func filteredActionMenuItems(_ query: String) -> [ActionMenuItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return actionMenuItems }
        return actionMenuItems.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Starts monitoring and loads history + settings.
    func onAppear() {
        Task {
            await self.loadSettingsAndHistory()
        }
        repository.startMonitoring()
        #if canImport(AppKit)
        updatePasteTargetApp()
        #endif
    }

    func toggleFavorite(_ item: ClipboardItem) {
        Task {
            do {
                _ = try await repository.toggleFavorite(id: item.id)
            } catch {
                showFooterStatus(FooterStatus(message: error.localizedDescription, kind: .error))
            }
        }
    }

    func toggleFavoriteSelected() {
        guard let selectedItem else { return }
        toggleFavorite(selectedItem)
    }

    func copy(_ item: ClipboardItem, closeAfterPaste: Bool, triggerPaste: Bool = false) {
        Task {
            do {
                try await repository.copyToClipboard(item)
                showFooterStatus(FooterStatus(message: "Copied to clipboard", kind: .success))
                if triggerPaste {
                    triggerSystemPaste()
                }
                if closeAfterPaste || settings.closeAfterPaste {
                    onCloseRequested?()
                }
            } catch {
                showFooterStatus(FooterStatus(message: error.localizedDescription, kind: .error))
            }
        }
    }

    func copySelected(closeAfterPaste: Bool, triggerPaste: Bool = false) {
        guard let selectedItem else { return }
        copy(selectedItem, closeAfterPaste: closeAfterPaste, triggerPaste: triggerPaste)
    }

    func paste() {
        performPasteSequence(closeAfterPaste: true)
    }

    func pasteKeepOpen() {
        performPasteSequence(closeAfterPaste: false, respectUserSetting: false)
    }

    func pasteAsPlainText() {
        // Content is already plain text; hook for future rich-text stripping.
        performPasteSequence(closeAfterPaste: true, forcePlainText: true)
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
            do {
                try await repository.clearHistory()
                showFooterStatus(FooterStatus(message: "Cleared history", kind: .warning))
            } catch {
                showFooterStatus(FooterStatus(message: error.localizedDescription, kind: .error))
            }
        }
    }

    func delete(_ item: ClipboardItem) {
        Task {
            do {
                try await repository.delete(id: item.id)
                showFooterStatus(FooterStatus(message: "Deleted entry", kind: .success))
            } catch {
                showFooterStatus(FooterStatus(message: error.localizedDescription, kind: .error))
            }
        }
    }

    func deleteSelected() {
        guard let selectedItem else { return }
        delete(selectedItem)
    }

    func clearNonFavorites() {
        Task {
            do {
                try await repository.clearNonFavorites()
                showFooterStatus(FooterStatus(message: "Cleared non-favorites", kind: .warning))
            } catch {
                showFooterStatus(FooterStatus(message: error.localizedDescription, kind: .error))
            }
        }
    }

    func togglePreview() {
        isPreviewVisible.toggle()
        settings.showPreview = isPreviewVisible
        Task {
            try? await settingsStore.save(settings)
        }
    }

    func openActionsOverlay() {
        // Placeholder hook for a richer actions overlay.
    }

    func showFooterStatus(_ status: FooterStatus, autoHideAfter seconds: Double = 3) {
        footerStatus = status
        let statusID = status.id

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard footerStatus?.id == statusID else { return }
            footerStatus = nil
        }
    }
    func performPasteSequence(
        closeAfterPaste: Bool = true,
        respectUserSetting: Bool = true,
        forcePlainText: Bool = false
    ) {
        guard let item = selectedItem else {
            showFooterStatus(FooterStatus(message: "Selecione um item para colar", kind: .warning))
            return
        }

        Task {
            let itemToCopy: ClipboardItem
            if forcePlainText {
                itemToCopy = ClipboardItem(
                    id: item.id,
                    capturedAt: item.capturedAt,
                    content: item.content,
                    type: .text,
                    isFavorite: item.isFavorite,
                    metadata: item.metadata
                )
            } else {
                itemToCopy = item
            }

            do {
                try await repository.copyToClipboard(itemToCopy)
            } catch {
                showFooterStatus(FooterStatus(message: error.localizedDescription, kind: .error))
                return
            }

            let shouldClose = closeAfterPaste || (respectUserSetting && settings.closeAfterPaste)
            if shouldClose {
                onCloseRequested?()
            }

            #if canImport(AppKit)
            if let targetApp = lastExternalApp {
                targetApp.activate(options: [.activateIgnoringOtherApps])
            }
            #endif

            // Wait for the previous app to regain focus before sending ⌘V
            try? await Task.sleep(nanoseconds: 160_000_000)
            triggerSystemPaste()

            await MainActor.run {
                showFooterStatus(FooterStatus(message: "Pasted", kind: .success))
            }
        }
    }

    private func triggerSystemPaste() {
        #if canImport(AppKit)
        let vKey: CGKeyCode = 9 // 'v'
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        #endif
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

    #if canImport(AppKit)
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func startTrackingFrontmostApplication() {
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalApp = current
        }
        updatePasteTargetApp()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lastExternalApp = app
                self.updatePasteTargetApp()
            }
        }
    }

    private func updatePasteTargetApp() {
        let target = lastExternalApp
        pasteTargetAppName = target?.localizedName ?? "Current App"
        pasteTargetAppIcon = target?.icon
    }
    #endif
}
