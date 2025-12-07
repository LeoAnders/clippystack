//
//  MainWindowView.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import SwiftUI
import AppKit

/// ClipBook/Raycast-style UI with search + filter at the top of the left panel
/// and actions at the top of the right panel.
struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var selection: UUID?
    @FocusState private var isSearchFocused: Bool
    @State private var windowConfigured: Bool = false

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

    // Global corner radius for the card/window
    private let windowCornerRadius: CGFloat = 10

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)

        return ZStack {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    leftHeader()
                    leftPanel()
                }
                .frame(
                    minWidth: 280,
                    idealWidth: 320,
                    maxWidth: viewModel.isPreviewVisible ? 360 : .infinity
                )

                if viewModel.isPreviewVisible {
                    verticalDivider()

                    VStack(spacing: 0) {
                        rightHeader()
                        rightPanel()
                    }
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(12)
        }
        // Single glass-like plate, Raycast style
        .background(
            cardShape
                .fill(.ultraThinMaterial)
        )
        .clipShape(cardShape)
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 16)
        .frame(minWidth: 780, minHeight: 480)
        .onAppear {
            viewModel.onAppear()
            isSearchFocused = true
        }
        .onReceive(viewModel.$selectedItem) { item in
            selection = item?.id
        }
        .background(WindowConfigurator(configured: $windowConfigured))
    }

    // MARK: - Vertical divider

    private func verticalDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Left Header (search + filtros)

    @ViewBuilder
    private func leftHeader() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RaycastSearchField(
                query: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.searchQuery = $0 }
                ),
                scope: Binding(
                    get: { viewModel.filterScope },
                    set: { viewModel.filterScope = $0 }
                ),
                isFocused: $isSearchFocused
            )

            HStack(spacing: 10) {
                Text("\(viewModel.displayedItems.count) items")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if !viewModel.isPreviewVisible {
                    Button {
                        viewModel.togglePreview()
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

    // MARK: - Right Header (preview actions)

    @ViewBuilder
    private func rightHeader() -> some View {
        HStack {
            // Top-left: copy + favorite
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

            // Top-right: sidebar + trash
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
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
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
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(Color.clear)
    }

    private func listRow(item: ClipboardItem) -> some View {
        let isSelected = selection == item.id
        let typeIcon = icon(for: item.type)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                Image(systemName: typeIcon)
                    .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.75))
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(makeSnippet(for: item.content))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.96))
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Right Panel (Preview + bottom info)

    @ViewBuilder
    private func rightPanel() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected = viewModel.selectedItem {
                ScrollView {
                    Text(selected.content)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }

                bottomDivider()

                VStack(alignment: .leading, spacing: 8) {
                    metadataRow(label: "Application", value: selected.metadata.sourceAppName ?? "Unknown")
                    metadataRow(label: "Bundle", value: selected.metadata.sourceBundleIdentifier ?? "—")
                    metadataRow(label: "Type", value: displayLabel(for: selected.type))
                    metadataRow(label: "Copy time", value: copyTimeFormatter.string(from: selected.capturedAt))
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "square.dashed.inset.filled")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Select an item")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func bottomDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 0)
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func makeSnippet(for content: String, maxLength: Int = 90) -> String {
        guard content.count > maxLength else { return content }
        return "\(content.prefix(maxLength))…"
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .bold()
            Text(value)
        }
    }

    private func icon(for type: ClipboardContentType) -> String {
        switch type {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .link:
            return "link"
        case .other:
            return "square.on.square"
        }
    }

    private func displayLabel(for type: ClipboardContentType) -> String {
        switch type {
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .link:
            return "Link"
        case .other:
            return "Other"
        }
    }
}

/// Search field styled to mimic Raycast's unified bar with inline type selector.
private struct RaycastSearchField: View {
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
                ForEach(ClipboardFilterScope.allCases) { option in
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
        // No external stroke to avoid a heavy border
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

private extension ClipboardFilterScope {
    var title: String {
        switch self {
        case .all:
            return "All"
        case .favorites:
            return "Favorites"
        case .text:
            return "Text"
        case .images:
            return "Images"
        case .links:
            return "Links"
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease"
        case .favorites:
            return "star"
        case .text:
            return "text.alignleft"
        case .images:
            return "photo"
        case .links:
            return "link"
        }
    }
}

/// Hides/configures the macOS window for the Raycast-style floating card.
private struct WindowConfigurator: NSViewRepresentable {
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

        // Borderless window with content filling the area
        window.styleMask = [
            .borderless,
            .fullSizeContentView,
            .resizable
        ]

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false            // shadow comes only from the SwiftUI card
        window.isMovableByWindowBackground = true

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
