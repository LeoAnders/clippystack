//
//  ClipboardTypes.swift
//  clippystack
//
//  Created by Leonardo Anders on 30/11/25.
//

import Foundation

/// Supported clipboard content categories.
enum ClipboardContentType: String, Codable, Sendable {
    case text
}

/// Metadata attached to clipboard items (kept small but extensible).
struct ClipboardMetadata: Codable, Sendable, Equatable {
    var sourceAppName: String?
    var sourceBundleIdentifier: String?
    var extra: [String: String]?

    init(
        sourceAppName: String? = nil,
        sourceBundleIdentifier: String? = nil,
        extra: [String: String]? = nil
    ) {
        self.sourceAppName = sourceAppName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.extra = extra
    }
}

/// Describes a keyboard shortcut (key + modifiers) for global actions.
struct KeyboardShortcutDescriptor: Codable, Sendable, Equatable {
    var key: String
    var modifiers: [KeyboardShortcutModifier]

    init(key: String, modifiers: [KeyboardShortcutModifier] = [.command]) {
        self.key = key
        self.modifiers = modifiers
    }
}

enum KeyboardShortcutModifier: String, Codable, Sendable {
    case command
    case option
    case control
    case shift
}
