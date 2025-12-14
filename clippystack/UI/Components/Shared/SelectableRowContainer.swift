//
//  SelectableRowContainer.swift
//  clippystack
//
//  Shared selection/hover styling for list and palette rows.
//

import SwiftUI

struct SelectableRowContainer<Content: View>: View {
    let isSelected: Bool
    let isEnabled: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var isHovering: Bool = false

    private var backgroundFill: Color {
        if isSelected { return Color.white.opacity(0.12) }
        if isHovering { return Color.white.opacity(0.06) }
        return Color.clear
    }

    private var strokeColor: Color {
        if isSelected { return Color.white.opacity(0.26) }
        if isHovering { return Color.white.opacity(0.14) }
        return Color.clear
    }

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: isSelected ? 1.2 : 1)
            )
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct KeyHintCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}
