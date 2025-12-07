//
//  MainWindowView.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import SwiftUI
import AppKit
import AppKit

struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var selection: UUID?
    @FocusState private var isSearchFocused: Bool
    @State private var windowConfigured: Bool = false
    @State private var isActionsPresented: Bool = false
    @State private var actionsSearchQuery: String = ""

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

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
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
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Spacer(minLength: 0)

                footerBar()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
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

    // MARK: - Footer

    private func footerTint(for status: FooterStatus?) -> LinearGradient {
        let base: Color
        switch status?.kind {
        case .success?:
            base = Color(red: 0.11, green: 0.35, blue: 0.23)
        case .warning?:
            base = Color(red: 0.45, green: 0.38, blue: 0.10)
        case .error?:
            base = Color(red: 0.45, green: 0.14, blue: 0.14)
        case .none:
            base = Color.black.opacity(0.35)
        }

        return LinearGradient(
            colors: [
                base.opacity(status == nil ? 0.18 : 0.38),
                base.opacity(status == nil ? 0.10 : 0.26)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var actionMenuItems: [ActionMenuItem] {
        let hasSelection = viewModel.selectedItem != nil
        let isFavorite = viewModel.selectedItem?.isFavorite ?? false
        let hasHistory = !viewModel.displayedItems.isEmpty

        return [
            ActionMenuItem(
                title: "Paste to \(viewModel.pasteTargetAppName)",
                icon: "arrow.turn.down.left",
                appIcon: viewModel.pasteTargetAppIcon,
                shortcutKeys: ["↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.paste() }
            ),
            ActionMenuItem(
                title: "Copy to Clipboard",
                icon: "doc.on.doc",
                appIcon: nil,
                shortcutKeys: ["⌘", "C"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.copySelected(closeAfterPaste: false) }
            ),
            ActionMenuItem(
                title: "Paste and Keep Window Open",
                icon: "arrow.triangle.2.circlepath",
                appIcon: viewModel.pasteTargetAppIcon,
                shortcutKeys: ["⌃", "⇧", "↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.pasteKeepOpen() }
            ),
            ActionMenuItem(
                title: "Paste as Plain Text",
                icon: "text.alignleft",
                appIcon: nil,
                shortcutKeys: ["⌥", "⇧", "↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.pasteAsPlainText() }
            ),
            ActionMenuItem(
                title: isFavorite ? "Remove Favorite" : "Add Favorite",
                icon: isFavorite ? "star.slash" : "star",
                appIcon: nil,
                shortcutKeys: ["⌘", "D"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.toggleFavoriteSelected() }
            ),
            ActionMenuItem(
                title: "Delete Item",
                icon: "trash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⌫"],
                role: .destructive,
                isEnabled: hasSelection,
                action: { viewModel.deleteSelected() }
            ),
            ActionMenuItem(
                title: "Clear All History",
                icon: "trash.slash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⇧", "⌫"],
                role: .destructive,
                isEnabled: hasHistory,
                action: { viewModel.clearHistoryRequest() }
            ),
            ActionMenuItem(
                title: "Clear Non-Favorites",
                icon: "star.slash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⌥", "⌫"],
                role: .destructive,
                isEnabled: hasHistory,
                action: { viewModel.clearNonFavorites() }
            )
        ]
    }

    private func footerBar() -> some View {
        let status = viewModel.footerStatus

        return HStack(spacing: 12) {
            if let status {
                ActionFeedbackBanner(status: status)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Spacer()

            FooterControlButton(
                title: "Paste to \(viewModel.pasteTargetAppName)",
                icon: "return",
                appIcon: viewModel.pasteTargetAppIcon,
                hintKeys: ["↩︎"]
            ) {
                viewModel.paste()
            }

            FooterControlButton(
                title: "Actions",
                icon: "ellipsis.circle",
                appIcon: nil,
                hintKeys: ["⌃", "K"]
            ) {
                if isActionsPresented {
                    isActionsPresented = false
                } else {
                    actionsSearchQuery = ""
                    isActionsPresented = true
                }
            }
            .popover(isPresented: $isActionsPresented, arrowEdge: .top) {
                ActionsPaletteView(
                    items: actionMenuItems,
                    searchText: $actionsSearchQuery
                ) { item in
                    isActionsPresented = false
                    item.action()
                }
                .padding(8)
            }
            .keyboardShortcut("k", modifiers: [.control])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)

                footerTint(for: status)
                    .blendMode(.plusLighter)

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.footerStatus)
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
            UnifiedSearchField(
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
                            Button("Delete") {
                                viewModel.delete(item)
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

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.top, 4)

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

/// Unified search field styled like a command palette with inline type selector.
private struct UnifiedSearchField: View {
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

// MARK: - Footer UI helpers

private struct ActionFeedbackBanner: View {
    let status: FooterStatus

    private var accentColor: Color {
        switch status.kind {
        case .success:
            return Color(red: 0.50, green: 0.89, blue: 0.58) // verde claro do “dot”
        case .warning:
            return Color(red: 1.0, green: 0.88, blue: 0.45)
        case .error:
            return Color(red: 1.0, green: 0.55, blue: 0.50)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)

            Text(status.message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.96))
        }
    }
}

private struct KeyHintCaps: View {
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

private struct FooterControlButton: View {
    let title: String
    let icon: String
    let appIcon: NSImage?
    let hintKeys: [String]?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .cornerRadius(4)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                }

                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))

                if let hintKeys, !hintKeys.isEmpty {
                    KeyHintCaps(keys: hintKeys)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct ActionMenuItem: Identifiable {
    enum Role {
        case normal
        case destructive
    }

    let id = UUID()
    let title: String
    let icon: String
    let appIcon: NSImage?
    let shortcutKeys: [String]
    let role: Role
    let isEnabled: Bool
    let action: () -> Void
}

private struct ActionsPaletteView: View {
    let items: [ActionMenuItem]
    @Binding var searchText: String
    let onSelect: (ActionMenuItem) -> Void

    private var filteredItems: [ActionMenuItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return items
        }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var normalItems: [ActionMenuItem] {
        filteredItems.filter { $0.role == .normal }
    }

    private var destructiveItems: [ActionMenuItem] {
        filteredItems.filter { $0.role == .destructive }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(normalItems) { item in
                        ActionRowView(item: item, onSelect: onSelect)
                    }

                    if !destructiveItems.isEmpty && !normalItems.isEmpty {
                        Divider()
                            .overlay(Color.white.opacity(0.16))
                            .padding(.horizontal, 6)
                    }

                    ForEach(destructiveItems) { item in
                        ActionRowView(item: item, onSelect: onSelect)
                    }
                }
                .padding(10)
            }

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
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ActionRowView: View {
    let item: ActionMenuItem
    let onSelect: (ActionMenuItem) -> Void

    @State private var isHovering: Bool = false
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
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconBackground)
                    if let nsImage = item.appIcon {
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
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovering ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
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
                .fill(Color.white.opacity(0.06))
        )
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

/// Hides/configures the macOS window for the floating card.
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
