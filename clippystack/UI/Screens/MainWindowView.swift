//
//  MainWindowView.swift
//  clippystack
//
//  Created by Leonardo Anders on 01/12/25.
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var selection: UUID?
    @FocusState private var isSearchFocused: Bool
    @State private var windowConfigured: Bool = false
    @State private var isActionsPresented: Bool = false
    @State private var actionsSearchQuery: String = ""
    @State private var highlightedActionID: ActionMenuItem.Identifier?
    @State private var visibleListRowIDs: Set<UUID> = []
    @State private var lastSelectionIndex: Int?

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
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.25),
                            Color(red: 0.17, green: 0.19, blue: 0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                cardShape
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.1)
        )
        .clipShape(cardShape)
        .shadow(color: Color.black.opacity(0.36), radius: 24, x: 0, y: 18)
        .frame(minWidth: 780, minHeight: 480)
        .onChange(of: viewModel.displayedItems.map(\.id)) { _, ids in
            visibleListRowIDs = visibleListRowIDs.intersection(Set(ids))
        }
        .overlay(alignment: .bottomTrailing) {
            if isActionsPresented {
                ZStack(alignment: .bottomTrailing) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isActionsPresented = false
                        }

                    ActionsPaletteView(
                        items: filteredActionMenuItems,
                        searchText: $actionsSearchQuery,
                        selectedID: $highlightedActionID
                    ) { item in
                        isActionsPresented = false
                        item.action()
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 54)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.onAppear()
            isSearchFocused = true
            normalizeActionSelection()
        }
        .onReceive(viewModel.$selectedItem) { item in
            selection = item?.id
        }
                .overlay(
                    KeyEventHandlingView { event in
                        handleKeyEvent(event)
                    }
                    .allowsHitTesting(false)
                    .frame(width: 0, height: 0)
                )
                .onChange(of: actionsSearchQuery) { _, _ in
                    normalizeActionSelection()
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
                id: .pasteToTargetApp,
                title: "Paste to \(viewModel.pasteTargetAppName)",
                icon: "arrow.turn.down.left",
                appIcon: viewModel.pasteTargetAppIcon,
                shortcutKeys: ["↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.paste() }
            ),
            ActionMenuItem(
                id: .copyToClipboard,
                title: "Copy to Clipboard",
                icon: "doc.on.doc",
                appIcon: nil,
                shortcutKeys: ["⌘", "C"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.copySelected(closeAfterPaste: false) }
            ),
            ActionMenuItem(
                id: .pasteKeepOpen,
                title: "Paste and Keep Window Open",
                icon: "arrow.triangle.2.circlepath",
                appIcon: viewModel.pasteTargetAppIcon,
                shortcutKeys: ["⌃", "⇧", "↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.pasteKeepOpen() }
            ),
            ActionMenuItem(
                id: .pasteAsPlainText,
                title: "Paste as Plain Text",
                icon: "text.alignleft",
                appIcon: nil,
                shortcutKeys: ["⌥", "⇧", "↩︎"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.pasteAsPlainText() }
            ),
            ActionMenuItem(
                id: .toggleFavorite,
                title: isFavorite ? "Remove Favorite" : "Add Favorite",
                icon: isFavorite ? "star.slash" : "star",
                appIcon: nil,
                shortcutKeys: ["⌘", "D"],
                role: .normal,
                isEnabled: hasSelection,
                action: { viewModel.toggleFavoriteSelected() }
            ),
            ActionMenuItem(
                id: .deleteItem,
                title: "Delete Item",
                icon: "trash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⌫"],
                role: .destructive,
                isEnabled: hasSelection,
                action: { viewModel.deleteSelected() }
            ),
            ActionMenuItem(
                id: .clearAllHistory,
                title: "Clear All History",
                icon: "trash.slash",
                appIcon: nil,
                shortcutKeys: ["⌘", "⇧", "⌫"],
                role: .destructive,
                isEnabled: hasHistory,
                action: { viewModel.clearHistoryRequest() }
            ),
            ActionMenuItem(
                id: .clearNonFavorites,
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

    private var filteredActionMenuItems: [ActionMenuItem] {
        let query = actionsSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return actionMenuItems }
        return actionMenuItems.filter { $0.title.localizedCaseInsensitiveContains(query) }
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
                toggleActionsPalette()
            }
            .keyboardShortcut("k", modifiers: [.control])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))

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
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                        .opacity(0.35)

                    ForEach(Array(viewModel.displayedItems.enumerated()), id: \.element.id) { _, item in
                        ClipboardListRow(
                            item: item,
                            isSelected: selection == item.id,
                            onSelect: {
                                selection = item.id
                                viewModel.selectedItem = item
                            },
                            onToggleFavorite: {
                                viewModel.toggleFavorite(item)
                            },
                            onCopy: {
                                viewModel.selectedItem = item
                                viewModel.copy(item, closeAfterPaste: false)
                            },
                            onDelete: {
                                viewModel.delete(item)
                            },
                            iconName: icon(for: item.type),
                            snippet: makeSnippet(for: item.content)
                        )
                        .tag(item.id)
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

    private struct ClipboardListRow: View {
        let item: ClipboardItem
        let isSelected: Bool
        let onSelect: () -> Void
        let onToggleFavorite: () -> Void
        let onCopy: () -> Void
        let onDelete: () -> Void
        let iconName: String
        let snippet: String

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

    private func toggleActionsPalette() {
        if isActionsPresented {
            isActionsPresented = false
        } else {
            actionsSearchQuery = ""
            resetActionSelection()
            isActionsPresented = true
        }
    }

    private func normalizeActionSelection() {
        let items = filteredActionMenuItems
        if let highlightedActionID, items.contains(where: { $0.id == highlightedActionID }) {
            return
        }
        highlightedActionID = items.first?.id
    }

    private func resetActionSelection() {
        highlightedActionID = filteredActionMenuItems.first?.id
    }

    private func handleKeyEvent(_ event: NSEvent) {
        switch event.keyCode {
        case 125: // Down arrow
            if isActionsPresented {
                moveActionSelection(offset: 1)
            } else {
                viewModel.selectNext()
            }
        case 126: // Up arrow
            if isActionsPresented {
                moveActionSelection(offset: -1)
            } else {
                viewModel.selectPrevious()
            }
        case 36: // Return
            if isActionsPresented, let id = highlightedActionID,
               let action = filteredActionMenuItems.first(where: { $0.id == id }) {
                isActionsPresented = false
                action.action()
            }
        case 53: // Escape
            if isActionsPresented {
                isActionsPresented = false
            }
        default:
            break
        }
    }

    private func moveActionSelection(offset: Int) {
        let items = filteredActionMenuItems
        guard !items.isEmpty else { return }
        guard let currentIndex = items.firstIndex(where: { $0.id == highlightedActionID }) else {
            highlightedActionID = items.first?.id
            return
        }
        let newIndex = max(items.startIndex, min(items.endIndex - 1, currentIndex + offset))
        highlightedActionID = items[newIndex].id
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
    enum Identifier: String {
        case pasteToTargetApp
        case copyToClipboard
        case pasteKeepOpen
        case pasteAsPlainText
        case toggleFavorite
        case deleteItem
        case clearAllHistory
        case clearNonFavorites
    }

    enum Role {
        case normal
        case destructive
    }

    let id: Identifier
    let title: String
    let icon: String
    let appIcon: NSImage?
    let shortcutKeys: [String]
    let role: Role
    let isEnabled: Bool
    let action: () -> Void
}

/// Shared selectable row container to unify hover/selection styling across lists and menus.
private struct SelectableRowContainer<Content: View>: View {
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

private struct ActionsPaletteView: View {
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
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(normalItems) { item in
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

                        ForEach(destructiveItems) { item in
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
                .onChange(of: items.map(\.id)) { _, _ in
                    scrollToSelection(selectedID, in: proxy)
                }
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
        .onChange(of: items.map(\.id)) { _, _ in
            if let selectedID, items.contains(where: { $0.id == selectedID }) {
                return
            }
            selectedID = items.first?.id
        }
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

#if canImport(AppKit)
private struct KeyEventHandlingView: NSViewRepresentable {
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
