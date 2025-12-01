//
//  MainWindowView.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import SwiftUI

/// Tela principal com lista de itens e painel de preview.
struct MainWindowView: View {
    @StateObject var viewModel: MainWindowViewModel
    @State private var selection: UUID?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            leftPane()
                .frame(minWidth: 320, maxWidth: 380)

            if viewModel.isPreviewVisible {
                Divider()
                previewPane()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.copySelectedAndCloseIfNeeded()
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                }
                .keyboardShortcut(.return, modifiers: [])

                Button {
                    viewModel.clearHistoryRequest()
                } label: {
                    Label("Limpar", systemImage: "trash")
                }

                Button {
                    viewModel.togglePreview()
                } label: {
                    Label("Preview", systemImage: viewModel.isPreviewVisible ? "sidebar.right" : "sidebar.right.hide")
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }
        .onAppear {
            viewModel.onAppear()
            isSearchFocused = true
        }
        .onReceive(viewModel.$selectedItem) { item in
            selection = item?.id
        }
    }

    @ViewBuilder
    private func leftPane() -> some View {
        VStack(spacing: 8) {
            SearchField(text: $viewModel.searchQuery)
                .focused($isSearchFocused)
                .padding([.top, .horizontal])

            Toggle(isOn: $viewModel.favoriteFilter) {
                Label("Favoritos", systemImage: "star.fill")
            }
            .toggleStyle(.switch)
            .padding(.horizontal)

            List(selection: Binding(
                get: { selection },
                set: { newValue in
                    selection = newValue
                    if let id = newValue,
                       let item = viewModel.displayedItems.first(where: { $0.id == id }) {
                        viewModel.selectedItem = item
                    }
                }
            )) {
                ForEach(viewModel.displayedItems) { item in
                    ClipboardRowView(
                        item: item,
                        isSelected: item.id == selection,
                        onToggleFavorite: { viewModel.toggleFavorite(item) }
                    )
                    .tag(item.id)
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private func previewPane() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
            }

            if let selected = viewModel.selectedItem {
                ScrollView {
                    Text(selected.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Selecione um item")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding()
        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.content)
                    .lineLimit(2)
                    .font(.body)
                Text(item.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundColor(item.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isFavorite ? "Remover dos favoritos" : "Adicionar aos favoritos")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        TextField("Buscar", text: $text)
            .textFieldStyle(.roundedBorder)
    }
}
