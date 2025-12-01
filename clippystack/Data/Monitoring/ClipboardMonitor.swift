//
//  ClipboardMonitor.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import AppKit
import Combine
import Foundation

/// Abstração fina sobre `NSPasteboard` para permitir teste e troca de implementação.
protocol PasteboardAdapter: Sendable {
    var changeCount: Int { get }
    func string(forType type: NSPasteboard.PasteboardType) -> String?
}

/// Adaptador padrão que usa `NSPasteboard.general`.
final class SystemPasteboardAdapter: PasteboardAdapter {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        pasteboard.string(forType: type)
    }
}

/// Monitora alterações no `NSPasteboard` e publica itens de texto únicos.
final class ClipboardMonitor {
    private let pasteboard: PasteboardAdapter
    private let queue: DispatchQueue
    private let pollInterval: TimeInterval
    private var lastChangeCount: Int
    private var lastContent: String?
    private var timer: DispatchSourceTimer?
    private let subject = PassthroughSubject<ClipboardItem, Never>()

    /// Combine publisher para novos itens de clipboard.
    var publisher: AnyPublisher<ClipboardItem, Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        pasteboard: PasteboardAdapter = SystemPasteboardAdapter(),
        pollInterval: TimeInterval = 0.6,
        queue: DispatchQueue = DispatchQueue(label: "clippystack.clipboard.monitor")
    ) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.queue = queue
        self.lastChangeCount = pasteboard.changeCount
    }

    /// Inicia o timer para varrer o pasteboard.
    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.pollPasteboard()
        }
        timer.resume()
        self.timer = timer
    }

    /// Interrompe o timer ativo.
    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Cria um `AsyncStream` que reflete o mesmo fluxo do publisher Combine.
    func makeAsyncStream() -> AsyncStream<ClipboardItem> {
        AsyncStream { continuation in
            let cancellable = subject.sink { continuation.yield($0) }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Realiza uma varredura imediata. Exposta para testes e para uso sem timer.
    func pollPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lastChangeCount = currentChangeCount

        guard
            let rawContent = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawContent.isEmpty
        else {
            return
        }

        guard rawContent != lastContent else {
            return
        }

        lastContent = rawContent
        let item = ClipboardItem(capturedAt: Date(), content: rawContent, type: .text)
        subject.send(item)
    }
}
