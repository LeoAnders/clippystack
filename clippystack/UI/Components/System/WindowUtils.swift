//
//  WindowUtils.swift
//  clippystack
//
//  Configures the macOS window to match the floating card style.
//

import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    @Binding var configured: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window, !configured else { return }
        configured = true

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [
            .borderless,
            .fullSizeContentView,
            .resizable
        ]

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
