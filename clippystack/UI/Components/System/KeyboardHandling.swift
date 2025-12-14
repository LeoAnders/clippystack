//
//  KeyboardHandling.swift
//  clippystack
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum KeyboardCommand {
    case moveList(Int)
    case moveAction(Int)
    case confirmAction
    case dismissActions
}

struct KeyboardCommandHandlerModifier: ViewModifier {
    @Binding var isActionsPresented: Bool
    let onCommand: (KeyboardCommand) -> Void
    private let mapper = KeyboardCommandMapper()

    func body(content: Content) -> some View {
        content
            .overlay(
                KeyEventHandlingView { event in
                    guard let command = mapper.map(event: event, isActionsPresented: isActionsPresented) else {
                        return
                    }
                    onCommand(command)
                }
                .allowsHitTesting(false)
                .frame(width: 0, height: 0)
            )
    }
}

extension View {
    func keyboardCommandHandler(
        isActionsPresented: Binding<Bool>,
        onCommand: @escaping (KeyboardCommand) -> Void
    ) -> some View {
        modifier(KeyboardCommandHandlerModifier(isActionsPresented: isActionsPresented, onCommand: onCommand))
    }
}

private struct KeyboardCommandMapper {
    func map(event: NSEvent, isActionsPresented: Bool) -> KeyboardCommand? {
        switch event.keyCode {
        case 125: // Down arrow
            return isActionsPresented ? .moveAction(1) : .moveList(1)
        case 126: // Up arrow
            return isActionsPresented ? .moveAction(-1) : .moveList(-1)
        case 36: // Return
            return isActionsPresented ? .confirmAction : nil
        case 53: // Escape
            return isActionsPresented ? .dismissActions : nil
        default:
            return nil
        }
    }
}

#if canImport(AppKit)
struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyCatcherView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.onKeyDown?(event)
            return event
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
#endif
