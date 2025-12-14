//
//  ClipboardContentPresentation.swift
//  clippystack
//
//  Presentation helpers for clipboard content types.
//

import Foundation

extension ClipboardContentType {
    var iconName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .link:
            return "link"
        case .other:
            return "square.on.square"
        }
    }

    var displayLabel: String {
        switch self {
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .link:
            return "Link"
        case .other:
            return "Other"
        }
    }
}
