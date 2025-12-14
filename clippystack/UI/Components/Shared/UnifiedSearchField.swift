//
//  UnifiedSearchField.swift
//  clippystack
//
//  Command-palette style search field with inline scope selector.
//

import SwiftUI

struct UnifiedSearchField: View {
    @Binding var query: String
    @Binding var scope: ClipboardFilterScope
    @FocusState.Binding var isFocused: Bool

    private let cornerRadius: CGFloat = 10

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 15, weight: .semibold))

            TextField("Search clips...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .focused($isFocused)
                .keyboardShortcut("f", modifiers: [.command])

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 20)

            Menu {
                ForEach(ClipboardFilterScope.allCases, id: \.self) { option in
                    Button {
                        scope = option
                    } label: {
                        Label(option.title, systemImage: option.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: scope.icon)
                    Text(scope.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: Capsule())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}
