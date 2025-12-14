//
//  PreviewDetailView.swift
//  clippystack
//

import SwiftUI

struct PreviewDetailView: View {
    let selectedItem: ClipboardItem?
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onTogglePreview: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.borderless)
                .help("Copy")

                Button(action: onToggleFavorite) {
                    let isFavorite = selectedItem?.isFavorite ?? false
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .white.opacity(0.6))
                }
                .buttonStyle(.borderless)
                .help("Toggle favorite")
            }

            Spacer()

            Button(action: onTogglePreview) {
                Image(systemName: "sidebar.right")
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .help("Hide preview")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected = selectedItem {
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
                    metadataRow(label: "Type", value: selected.type.displayLabel)
                    metadataRow(label: "Copy time", value: ClipboardFormatters.copyTime.string(from: selected.capturedAt))
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

    @ViewBuilder
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .bold()
            Text(value)
        }
    }
}
