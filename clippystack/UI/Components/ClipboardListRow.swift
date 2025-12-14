//
//  ClipboardListRow.swift
//  clippystack
//

import SwiftUI

struct ClipboardListRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let iconName: String
    let snippet: String
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SelectableRowContainer(isSelected: isSelected, isEnabled: true, horizontalPadding: 10, verticalPadding: 6) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: iconName)
                        .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.78))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.96))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(item.isFavorite ? .yellow : .white.opacity(0.45))
                }
                .buttonStyle(.borderless)
            }
        }
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Copy") { onCopy() }
            Button(item.isFavorite ? "Remove favorite" : "Add favorite") { onToggleFavorite() }
            Button("Delete") { onDelete() }
        }
    }
}
