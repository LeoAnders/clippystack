//
//  ClipboardFilterScope+UI.swift
//  clippystack
//

import Foundation

extension ClipboardFilterScope {
    var title: String {
        switch self {
        case .all:
            return "All"
        case .favorites:
            return "Favorites"
        case .text:
            return "Text"
        case .images:
            return "Images"
        case .links:
            return "Links"
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease"
        case .favorites:
            return "star"
        case .text:
            return "text.alignleft"
        case .images:
            return "photo"
        case .links:
            return "link"
        }
    }
}
