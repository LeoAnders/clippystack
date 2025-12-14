//
//  ActionMenuItem.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

struct ActionMenuItem: Identifiable {
    enum Identifier: String {
        case pasteToTargetApp
        case copyToClipboard
        case pasteKeepOpen
        case pasteAsPlainText
        case toggleFavorite
        case deleteItem
        case clearAllHistory
        case clearNonFavorites
    }

    enum Role {
        case normal
        case destructive
    }

    let id: Identifier
    let title: String
    let icon: String
    #if canImport(AppKit)
    let appIcon: NSImage?
    #else
    let appIcon: Any?
    #endif
    let shortcutKeys: [String]
    let role: Role
    let isEnabled: Bool
    let action: () -> Void
}
