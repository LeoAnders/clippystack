//
//  ClipboardFormatters.swift
//  clippystack
//
//  Centralized date formatters to avoid recreating them on every render.
//

import Foundation

enum ClipboardFormatters {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static let copyTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
