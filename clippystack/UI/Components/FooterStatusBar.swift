//
//  FooterStatusBar.swift
//  clippystack
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct FooterStatusBar: View {
    let status: FooterStatus?
    let pasteTargetAppName: String
    #if canImport(AppKit)
    let pasteTargetAppIcon: NSImage?
    #else
    let pasteTargetAppIcon: Any?
    #endif
    let onPaste: () -> Void
    let onActions: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let status {
                ActionFeedbackBanner(status: status)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()

            FooterControlButton(
                title: "Paste to \(pasteTargetAppName)",
                icon: "return",
                appIcon: pasteTargetAppIcon,
                hintKeys: ["↩︎"],
                action: onPaste
            )

            FooterControlButton(
                title: "Actions",
                icon: "ellipsis.circle",
                appIcon: nil,
                hintKeys: ["⌃", "K"],
                action: onActions
            )
            .keyboardShortcut("k", modifiers: [.control])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))

                footerTint(for: status)
                    .blendMode(.plusLighter)

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: status)
    }

    private func footerTint(for status: FooterStatus?) -> LinearGradient {
        let base: Color
        switch status?.kind {
        case .success?:
            base = Color(red: 0.11, green: 0.35, blue: 0.23)
        case .warning?:
            base = Color(red: 0.45, green: 0.38, blue: 0.10)
        case .error?:
            base = Color(red: 0.45, green: 0.14, blue: 0.14)
        case .none:
            base = Color.black.opacity(0.35)
        }

        return LinearGradient(
            colors: [
                base.opacity(status == nil ? 0.18 : 0.38),
                base.opacity(status == nil ? 0.10 : 0.26)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
