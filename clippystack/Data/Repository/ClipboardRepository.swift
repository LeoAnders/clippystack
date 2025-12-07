//
//  ClipboardRepository.swift
//  clippystack
//
//  Created by Leonardo Anders on 30/11/25.
//

import Combine
import Foundation

/// Abstracts core clipboard history operations.
protocol ClipboardRepository: Sendable {
    /// Observable stream of items for UI/ViewModels.
    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> { get }

    /// Starts clipboard monitoring and the internal update pipeline.
    func startMonitoring()

    /// Retrieves the current in-memory history state.
    func currentItems() async -> [ClipboardItem]

    /// Persists and returns the latest history from storage.
    func reloadHistory() async throws -> [ClipboardItem]

    /// Toggles favorite and returns the updated item if present.
    func toggleFavorite(id: UUID) async throws -> ClipboardItem?

    /// Deletes a clipboard entry and persists the change.
    func delete(id: UUID) async throws

    /// Removes all history items and persists the change.
    func clearHistory() async throws

    /// Removes non-favorite items and persists the change.
    func clearNonFavorites() async throws

    /// Copies a selected item back to the system clipboard.
    func copyToClipboard(_ item: ClipboardItem) async throws
}
