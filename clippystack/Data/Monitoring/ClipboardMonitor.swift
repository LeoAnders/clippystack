//
//  ClipboardMonitor.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import AppKit
import Combine
import Foundation

/// Thin abstraction over `NSPasteboard` to enable testing and swapping implementations.
protocol PasteboardAdapter: Sendable {
    var changeCount: Int { get }
    func string(forType type: NSPasteboard.PasteboardType) -> String?
}

/// Default adapter backed by `NSPasteboard.general`.
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

/// Monitors `NSPasteboard` changes and publishes unique text items.
final class ClipboardMonitor {
    private let pasteboard: PasteboardAdapter
    private let queue: DispatchQueue
    private let pollInterval: TimeInterval
    private var lastChangeCount: Int
    private var lastContent: String?
    private var timer: DispatchSourceTimer?
    private let subject = PassthroughSubject<ClipboardItem, Never>()

    /// Combine publisher for new clipboard items.
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

    /// Starts the timer to poll the pasteboard.
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

    /// Stops the active timer.
    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Creates an `AsyncStream` that mirrors the Combine publisher.
    func makeAsyncStream() -> AsyncStream<ClipboardItem> {
        AsyncStream { continuation in
            let cancellable = subject.sink { continuation.yield($0) }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Performs an immediate scan; exposed for tests and manual polling.
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
        let item = ClipboardItem(
            capturedAt: Date(),
            content: rawContent,
            type: determineContentType(from: rawContent)
        )
        subject.send(item)
    }

    private func determineContentType(from string: String) -> ClipboardContentType {
        // Placeholder for richer detection (images/files); current monitor only reads text.
        if let url = URL(string: string), url.scheme != nil {
            return .link
        }
        return .text
    }
}
