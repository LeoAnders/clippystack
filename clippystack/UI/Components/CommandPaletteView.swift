//
//  CommandPaletteView.swift
//  clippystack
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct CommandPaletteView: View {
    let items: [ActionMenuItem]
    @Binding var searchText: String
    @Binding var selectedID: ActionMenuItem.Identifier?
    let onSelect: (ActionMenuItem) -> Void

    private var normalItems: [ActionMenuItem] {
        items.filter { $0.role == .normal }
    }

    private var destructiveItems: [ActionMenuItem] {
        items.filter { $0.role == .destructive }
    }

    var body: some View {
        let normal = normalItems
        let destructive = destructiveItems
        let itemIDs = items.map(\.id)

        VStack(spacing: 0) {
            PaletteList(
                normalItems: normal,
                destructiveItems: destructive,
                selectedID: $selectedID,
                itemIDs: itemIDs,
                onSelect: onSelect
            )

            ActionSearchField(text: $searchText)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
        }
        .frame(width: 320)
        .frame(maxHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.18, blue: 0.30),
                            Color(red: 0.20, green: 0.22, blue: 0.36)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.30), radius: 20, x: 0, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            if selectedID == nil {
                selectedID = items.first?.id
            }
        }
        .onChange(of: itemIDs) { _, _ in
            guard let current = selectedID else {
                selectedID = items.first?.id
                return
            }
            if items.contains(where: { $0.id == current }) {
                return
            }
            selectedID = items.first?.id
        }
    }
}

private struct PaletteList: View {
    let normalItems: [ActionMenuItem]
    let destructiveItems: [ActionMenuItem]
    @Binding var selectedID: ActionMenuItem.Identifier?
    let itemIDs: [ActionMenuItem.Identifier]
    let onSelect: (ActionMenuItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(normalItems, id: \.id) { item in
                        ActionRowView(
                            item: item,
                            isSelected: selectedID == item.id,
                            onSelect: onSelect
                        )
                        .id(item.id)
                    }

                    if !destructiveItems.isEmpty && !normalItems.isEmpty {
                        Divider()
                            .overlay(Color.white.opacity(0.16))
                            .padding(.horizontal, 6)
                    }

                    ForEach(destructiveItems, id: \.id) { item in
                        ActionRowView(
                            item: item,
                            isSelected: selectedID == item.id,
                            onSelect: onSelect
                        )
                        .id(item.id)
                    }
                }
                .padding(10)
                .padding(.bottom, 4)
            }
            .onAppear {
                scrollToSelection(selectedID, in: proxy)
            }
            .onChange(of: selectedID) { _, newValue in
                scrollToSelection(newValue, in: proxy)
            }
            .onChange(of: itemIDs) { _, _ in
                scrollToSelection(selectedID, in: proxy)
            }
        }
    }
}

private struct ActionRowView: View {
    let item: ActionMenuItem
    let isSelected: Bool
    let onSelect: (ActionMenuItem) -> Void

    @Environment(\.isEnabled) private var isEnabled

    private var iconBackground: Color {
        item.role == .destructive
            ? Color.red.opacity(0.18)
            : Color.white.opacity(0.08)
    }

    private var iconColor: Color {
        item.role == .destructive
            ? Color(red: 1.0, green: 0.55, blue: 0.50)
            : Color.white.opacity(0.92)
    }

    var body: some View {
        Button {
            onSelect(item)
        } label: {
            SelectableRowContainer(isSelected: isSelected, isEnabled: isEnabled, horizontalPadding: 9, verticalPadding: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconBackground)
                        if let nsImage = item.appIcon as? NSImage {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .cornerRadius(4)
                        } else {
                            Image(systemName: item.icon)
                                .foregroundColor(iconColor)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .frame(width: 32, height: 32)

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(item.role == .destructive ? iconColor : .white.opacity(0.92))
                        .lineLimit(1)

                    Spacer()

                    if !item.shortcutKeys.isEmpty {
                        KeyHintCaps(keys: item.shortcutKeys)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!item.isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

private struct ActionSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 13, weight: .semibold))

            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

/// Shared helper to keep a selected row visible inside scrollable palettes/lists.
private func scrollToSelection<ID: Hashable>(
    _ selection: ID?,
    in proxy: ScrollViewProxy,
    anchor: UnitPoint? = nil
) {
    guard let selection else { return }
    withAnimation(.easeInOut(duration: 0.12)) {
        proxy.scrollTo(selection, anchor: anchor)
    }
}
