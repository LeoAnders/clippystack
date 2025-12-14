//
//  FooterControlButton.swift
//  clippystack
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct FooterControlButton: View {
    let title: String
    let icon: String
    #if canImport(AppKit)
    let appIcon: NSImage?
    #else
    let appIcon: Any?
    #endif
    let hintKeys: [String]?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let appIcon = appIcon as? NSImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .cornerRadius(4)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                }

                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))

                if let hintKeys, !hintKeys.isEmpty {
                    KeyHintCaps(keys: hintKeys)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
