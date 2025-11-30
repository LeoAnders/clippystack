//
//  ClipboardModels.swift
//  clippystack
//
//  Created by Leonardo Anders on 30/11/25.
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let capturedAt: Date
    var content: String
    var type: ClipboardContentType
    var isFavorite: Bool
    var metadata: ClipboardMetadata

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        content: String,
        type: ClipboardContentType = .text,
        isFavorite: Bool = false,
        metadata: ClipboardMetadata = .init()
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.content = content
        self.type = type
        self.isFavorite = isFavorite
        self.metadata = metadata
    }
}

struct AppSettings: Codable, Sendable, Equatable {
    private static let defaultHistoryLimit = 100

    var historyLimit: Int
    var closeAfterPaste: Bool
    var launchAtLogin: Bool
    var showPreview: Bool
    var globalShortcut: KeyboardShortcutDescriptor

    init(
        historyLimit: Int = Self.defaultHistoryLimit,
        closeAfterPaste: Bool = false,
        launchAtLogin: Bool = false,
        showPreview: Bool = true,
        globalShortcut: KeyboardShortcutDescriptor = .init(key: "v", modifiers: [.command, .shift])
    ) {
        self.historyLimit = max(1, historyLimit)
        self.closeAfterPaste = closeAfterPaste
        self.launchAtLogin = launchAtLogin
        self.showPreview = showPreview
        self.globalShortcut = globalShortcut
    }
}
