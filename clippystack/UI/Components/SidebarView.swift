//
//  SidebarView.swift
//  clippystack
//

import SwiftUI

struct SidebarView: View {
    let items: [ClipboardItem]
    let selection: UUID?
    let filterScope: ClipboardFilterScope
    let searchQuery: String
    let isPreviewVisible: Bool
    let onSelectItem: (ClipboardItem) -> Void
    let onToggleFavorite: (ClipboardItem) -> Void
    let onCopy: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onFilterChange: (ClipboardFilterScope) -> Void
    let onSearchChange: (String) -> Void
    let onTogglePreview: () -> Void

    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            list
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            UnifiedSearchField(
                query: Binding(
                    get: { searchQuery },
                    set: { onSearchChange($0) }
                ),
                scope: Binding(
                    get: { filterScope },
                    set: { onFilterChange($0) }
                ),
                isFocused: $isSearchFocused
            )

            HStack(spacing: 10) {
                Text("\(items.count) items")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if !isPreviewVisible {
                    Button {
                        onTogglePreview()
                    } label: {
                        Label("Show preview", systemImage: "sidebar.right")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.borderless)
                    .help("Show preview")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                        .opacity(0.35)

                    ForEach(items) { item in
                        ClipboardListRow(
                            item: item,
                            isSelected: selection == item.id,
                            iconName: item.type.iconName,
                            snippet: makeSnippet(for: item.content),
                            onSelect: { onSelectItem(item) },
                            onToggleFavorite: { onToggleFavorite(item) },
                            onCopy: { onCopy(item) },
                            onDelete: { onDelete(item) }
                        )
                        .id(item.id)
                    }
                }
            }
            .onChange(of: selection) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: nil)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(Color.clear)
    }

    private func makeSnippet(for content: String, maxLength: Int = 90) -> String {
        guard content.count > maxLength else { return content }
        return "\(content.prefix(maxLength))…"
    }
}
