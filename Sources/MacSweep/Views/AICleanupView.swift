import SwiftUI
import AppKit

public struct AICleanupView: View {
    @ObservedObject var appState: AppState
    @StateObject private var aiService = AICleanupService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRetentionDays: Int = 14
    @State private var isCleaning: Bool = false
    @State private var cleanResultText: String?

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var groupedItems: [AIToolCategory: [AIItem]] {
        Dictionary(grouping: aiService.items, by: { $0.category })
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 16) {
                if let moonImg = AssetLoader.loadNSImage(named: "planet-static-moon") {
                    Image(nsImage: moonImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .shadow(color: .purple.opacity(0.3), radius: 8)
                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("AI Tool Cleanup & Care")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Moon Sub-Tab")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.2)))
                            .foregroundColor(.purple)
                    }

                    Text("The moon draws a thousand tides away. In its mirror, ten thousand words fall still.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main Content Area
            ScrollView {
                VStack(spacing: 20) {
                    // Retention Period Filter
                    HStack(spacing: 12) {
                        Text("Chat Session Age:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach([7, 14, 30, 90], id: \.self) { days in
                            Button(action: {
                                selectedRetentionDays = days
                            }) {
                                Text("Older than \(days)d")
                                    .font(.caption)
                                    .fontWeight(selectedRetentionDays == days ? .bold : .regular)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule().fill(selectedRetentionDays == days ? Color.purple : Color.gray.opacity(0.15))
                                    )
                                    .foregroundColor(selectedRetentionDays == days ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button(action: {
                            Task {
                                await aiService.scanAIData()
                            }
                        }) {
                            Label(aiService.isScanning ? "Scanning..." : "Rescan AI Data", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(aiService.isScanning)
                    }
                    .padding(.horizontal, 4)

                    // Notice if no items
                    if aiService.items.isEmpty && !aiService.isScanning {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.green)
                            Text("No Bloated AI Tool Data Detected")
                                .font(.headline)
                            Text("Your Claude Code, Codex, Cursor and Ollama caches are lean and tidy.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Categories List
                        ForEach(AIToolCategory.allCases) { category in
                            if let items = groupedItems[category], !items.isEmpty {
                                aiCategorySection(category: category, items: items)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Bottom Action Bar
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Selected for Removal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(aiService.selectedBytes.formattedBytes)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(aiService.selectedBytes > 0 ? .purple : .secondary)
                }

                Spacer()

                if let res = cleanResultText {
                    Text(res)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Button(action: {
                    Task {
                        isCleaning = true
                        let result = await aiService.cleanSelectedItems(useTrash: true)
                        isCleaning = false
                        cleanResultText = "Cleaned \(result.cleanedBytes.formattedBytes) from \(result.cleanedCount) AI items!"
                        appState.refreshStorageOverview()
                    }
                }) {
                    HStack {
                        if isCleaning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Clean AI Data (\(aiService.selectedBytes.formattedBytes))")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.purple)
                .disabled(aiService.selectedBytes == 0 || isCleaning)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            Task {
                await aiService.scanAIData()
            }
        }
    }

    @ViewBuilder
    private func aiCategorySection(category: AIToolCategory, items: [AIItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.headline)
                    Text(category.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Select All") {
                    aiService.selectAll(in: category, select: true)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.purple)

                Button("Deselect All") {
                    aiService.selectAll(in: category, select: false)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { item.isSelected },
                            set: { _ in aiService.toggleItemSelection(item.id) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(item.toolName)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.gray.opacity(0.18)))
                                    .foregroundColor(.secondary)

                                if item.ageInDays > 0 {
                                    Text("\(item.ageInDays)d old")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(item.detail)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(item.size.formattedBytes)
                            .font(.caption)
                            .fontWeight(.semibold)

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([item.path])
                        }) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if item.id != items.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
        }
    }
}
