//
//  MainWindowView.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import SwiftUI

/// UI estilo ClipBook/Raycast com busca + filtro no topo do painel esquerdo
/// e ações no topo do painel direito.
struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var selection: UUID?
    @FocusState private var isSearchFocused: Bool

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private let copyTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            // Deixa o fundo da janela transparente para usar o blur do próprio macOS
            Color.clear.ignoresSafeArea()

            HStack(spacing: 0) {
                // MARK: - COLUNA ESQUERDA (header + lista)
                VStack(spacing: 0) {
                    leftHeader()
                    leftPanel()
                }
                .frame(
                    minWidth: 260,
                    idealWidth: 300,
                    maxWidth: viewModel.isPreviewVisible ? 340 : .infinity
                )
                .frame(maxHeight: .infinity)
                .background(
                    .ultraThinMaterial.opacity(0.55) // mais transparente
                )
                .overlay(
                    Color.white.opacity(0.02)
                        .allowsHitTesting(false)      // não bloqueia cliques
                )

                // MARK: - DIVISOR + COLUNA DIREITA
                if viewModel.isPreviewVisible {
                    verticalDivider()

                    VStack(spacing: 0) {
                        rightHeader()
                        rightPanel()
                    }
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        .ultraThinMaterial.opacity(0.60) // mais transparente também
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.14),
                                Color.black.opacity(0.09)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)       // não intercepta eventos
                    )
                }
            }
        }
        .frame(minWidth: 760, minHeight: 460)
        .onAppear {
            viewModel.onAppear()
            isSearchFocused = true
        }
        .onReceive(viewModel.$selectedItem) { item in
            selection = item?.id
        }
    }

    // MARK: - Vertical divider

    private func verticalDivider() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1)
    }

    // MARK: - Left Header (search + filtros)

    @ViewBuilder
    private func leftHeader() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundColor(.secondary)

                    TextField(
                        "Type to search...",
                        text: Binding(
                            get: { viewModel.searchQuery },
                            set: { viewModel.searchQuery = $0 }
                        )
                    )
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .keyboardShortcut("f", modifiers: [.command])
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                if !viewModel.isPreviewVisible {
                    Button {
                        viewModel.togglePreview()
                    } label: {
                        Image(systemName: "sidebar.right")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.borderless)
                    .help("Show preview")
                }
            }

            Picker("", selection: Binding(
                get: { viewModel.favoriteFilter },
                set: { viewModel.favoriteFilter = $0 }
            )) {
                Label("All", systemImage: "line.3.horizontal").tag(false)
                Label("Favorites", systemImage: "star").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Right Header (ações do preview)

    @ViewBuilder
    private func rightHeader() -> some View {
        HStack {
            // canto superior ESQUERDO: copy + favorite
            HStack(spacing: 10) {
                Button {
                    viewModel.copySelected(closeAfterPaste: false)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.borderless)
                .help("Copy")

                Button {
                    viewModel.toggleFavoriteSelected()
                } label: {
                    Image(systemName: (viewModel.selectedItem?.isFavorite ?? false) ? "star.fill" : "star")
                        .foregroundColor((viewModel.selectedItem?.isFavorite ?? false)
                                         ? .yellow
                                         : .white.opacity(0.6))
                }
                .buttonStyle(.borderless)
                .help("Toggle favorite")
            }

            Spacer()

            // canto superior DIREITO: sidebar + trash
            HStack(spacing: 10) {
                Button {
                    viewModel.togglePreview()
                } label: {
                    Image(systemName: "sidebar.right")
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.borderless)
                .help("Hide preview")

                Button {
                    viewModel.clearHistoryRequest()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.borderless)
                .help("Clear history")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Left Panel (List)

    @ViewBuilder
    private func leftPanel() -> some View {
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
            ForEach(Array(viewModel.displayedItems.enumerated()), id: \.element.id) { _, item in
                listRow(item: item)
                    .tag(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = item.id
                        viewModel.selectedItem = item
                    }
                    .contextMenu {
                        Button("Copy") {
                            viewModel.selectedItem = item
                            viewModel.copy(item, closeAfterPaste: false)
                        }
                        Button(item.isFavorite ? "Remove favorite" : "Add favorite") {
                            viewModel.toggleFavorite(item)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func listRow(item: ClipboardItem) -> some View {
        let isSelected = selection == item.id

        return HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.75))
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(makeSnippet(for: item.content))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button {
                viewModel.toggleFavorite(item)
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(item.isFavorite ? .yellow : .white.opacity(0.45))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
    }

    // MARK: - Right Panel (Preview + bottom info)

    @ViewBuilder
    private func rightPanel() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected = viewModel.selectedItem {
                // Conteúdo
                ScrollView {
                    Text(selected.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }

                // Linha separadora acima do bottom
                bottomDivider()

                // Metadados no rodapé, incluindo Copy time
                VStack(alignment: .leading, spacing: 4) {
                    metadataRow(label: "Application", value: selected.metadata.sourceAppName ?? "Unknown")
                    metadataRow(label: "Bundle", value: selected.metadata.sourceBundleIdentifier ?? "—")
                    metadataRow(label: "Type", value: "Text")
                    metadataRow(label: "Copy time", value: copyTimeFormatter.string(from: selected.capturedAt))
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 10)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Select an item")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func bottomDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func makeSnippet(for content: String, maxLength: Int = 90) -> String {
        guard content.count > maxLength else { return content }
        return "\(content.prefix(maxLength))…"
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .bold()
            Text(value)
        }
    }
}
