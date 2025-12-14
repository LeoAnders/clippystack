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

    // Global corner radius for the card/window
    private let windowCornerRadius: CGFloat = 10

    private var filteredActionMenuItems: [ActionMenuItem] {
        viewModel.filteredActionMenuItems(actionsSearchQuery)
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    SidebarView(
                        items: viewModel.displayedItems,
                        selection: selection,
                        filterScope: viewModel.filterScope,
                        searchQuery: viewModel.searchQuery,
                        isPreviewVisible: viewModel.isPreviewVisible,
                        onSelectItem: { item in
                            selection = item.id
                            viewModel.selectedItem = item
                        },
                        onToggleFavorite: { item in
                            viewModel.toggleFavorite(item)
                        },
                        onCopy: { item in
                            viewModel.selectedItem = item
                            viewModel.copy(item, closeAfterPaste: false)
                        },
                        onDelete: { item in
                            viewModel.delete(item)
                        },
                        onFilterChange: { viewModel.filterScope = $0 },
                        onSearchChange: { viewModel.searchQuery = $0 },
                        onTogglePreview: { viewModel.togglePreview() },
                        isSearchFocused: $isSearchFocused
                    )
                    .frame(
                        minWidth: 280,
                        idealWidth: 320,
                        maxWidth: viewModel.isPreviewVisible ? 360 : .infinity
                    )

                    if viewModel.isPreviewVisible {
                        verticalDivider()

                        PreviewDetailView(
                            selectedItem: viewModel.selectedItem,
                            onCopy: { viewModel.copySelected(closeAfterPaste: false) },
                            onToggleFavorite: { viewModel.toggleFavoriteSelected() },
                            onTogglePreview: { viewModel.togglePreview() }
                        )
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Spacer(minLength: 0)

                FooterStatusBar(
                    status: viewModel.footerStatus,
                    pasteTargetAppName: viewModel.pasteTargetAppName,
                    pasteTargetAppIcon: viewModel.pasteTargetAppIcon,
                    onPaste: { viewModel.paste() },
                    onActions: { toggleActionsPalette() }
                )
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
        .overlay(alignment: .bottomTrailing) {
            if isActionsPresented {
                ZStack(alignment: .bottomTrailing) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isActionsPresented = false
                        }

                    CommandPaletteView(
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
        .onChange(of: actionsSearchQuery) { _, _ in
            normalizeActionSelection()
        }
        .keyboardCommandHandler(isActionsPresented: $isActionsPresented) { command in
            handleKeyboardCommand(command)
        }
        .background(WindowConfigurator(configured: $windowConfigured))
    }

    private func verticalDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
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

    private func handleKeyboardCommand(_ command: KeyboardCommand) {
        switch command {
        case .moveList(let offset):
            if offset > 0 {
                viewModel.selectNext()
            } else {
                viewModel.selectPrevious()
            }
        case .moveAction(let offset):
            moveActionSelection(offset: offset)
        case .confirmAction:
            triggerHighlightedAction()
        case .dismissActions:
            isActionsPresented = false
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

    private func triggerHighlightedAction() {
        guard isActionsPresented,
              let id = highlightedActionID,
              let action = filteredActionMenuItems.first(where: { $0.id == id }) else { return }
        isActionsPresented = false
        action.action()
    }
}
