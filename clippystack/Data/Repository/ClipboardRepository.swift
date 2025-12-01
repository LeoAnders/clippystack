//
//  ClipboardRepository.swift
//  clippystack
//
//  Created by Leonardo Anders on 30/11/25.
//

import Combine
import Foundation

/// Abstrai operações centrais de histórico do clipboard.
protocol ClipboardRepository: Sendable {
    /// Fluxo de itens observável para UI/ViewModels.
    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> { get }

    /// Inicia monitoramento do clipboard e fluxo de atualização interna.
    func startMonitoring()

    /// Recupera o estado atual do histórico em memória.
    func currentItems() async -> [ClipboardItem]

    /// Persiste e retorna o histórico mais recente do armazenamento.
    func reloadHistory() async throws -> [ClipboardItem]

    /// Marca/desmarca favorito e retorna o item atualizado se existir.
    func toggleFavorite(id: UUID) async throws -> ClipboardItem?

    /// Remove todos os itens do histórico e persiste a mudança.
    func clearHistory() async throws

    /// Copia um item selecionado de volta para o clipboard do sistema.
    func copyToClipboard(_ item: ClipboardItem) async throws
}
