import SwiftUI
import AppKit

public struct CleanView: View {
    @ObservedObject var appState: AppState
    @State private var expandedCategories: Set<CandidateCategory> = [.appDataAndLeftovers, .cachesAndTemp]
    @State private var showCleanConfirmAlert: Bool = false
    @State private var cleanPermanently: Bool = false

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var groupedCandidates: [CandidateCategory: [CleanupCandidate]] {
        Dictionary(grouping: appState.candidates, by: { $0.category })
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Celestial Hero Header
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.12), Color.teal.opacity(0.06), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.blue.opacity(0.15), lineWidth: 1)
                        )

                    HStack(spacing: 24) {
                        // Earth Planet Visual
                        ZStack {
                            Circle()
                                .fill(RadialGradient(
                                    colors: [Color.blue.opacity(0.4), Color.clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 70
                                ))
                                .frame(width: 140, height: 140)

                            if let earthImg = AssetLoader.loadNSImage(named: "planet-static-earth") {
                                Image(nsImage: earthImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 4)
                            } else {
                                Image(systemName: "globe.americas.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.blue)
                            }
                        }

                        // Hero Text & Motto
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Earth runs Clean")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Spacer()

                                // Moon Sub-Entry (AI Cleanup & Care)
                                Button(action: {
                                    appState.showAICleanupView = true
                                }) {
                                    HStack(spacing: 6) {
                                        if let moonImg = AssetLoader.loadNSImage(named: "planet-static-moon") {
                                            Image(nsImage: moonImg)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 18, height: 18)
                                        } else {
                                            Image(systemName: "moon.stars.fill")
                                                .foregroundColor(.yellow)
                                        }
                                        Text("AI Cleanup & Care")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.purple.opacity(0.15)))
                                    .overlay(Capsule().strokeBorder(Color.purple.opacity(0.3), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Clean up AI tool data (Claude, Codex, Cursor, Ollama)")
                            }

                            Text(NavigationSection.clean.poem)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .italic()

                            Divider()
                                .padding(.vertical, 4)

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cleanable Junk")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(appState.safeReclaimableBytes > 0 ? appState.safeReclaimableBytes.formattedBytes : (appState.isScanning ? "Scanning..." : "Clean"))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(appState.safeReclaimableBytes > 0 ? .primary : .green)
                                }

                                Spacer()

                                // Actions
                                HStack(spacing: 12) {
                                    Button(action: {
                                        appState.startComprehensiveScan()
                                    }) {
                                        Label(appState.isScanning ? "Scanning..." : "Rescan", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                    .disabled(appState.isScanning)

                                    Button(action: {
                                        cleanPermanently = false
                                        showCleanConfirmAlert = true
                                    }) {
                                        Label("Move to Trash (\(appState.totalSelectedBytes > 0 ? appState.totalSelectedBytes.formattedBytes : appState.safeReclaimableBytes.formattedBytes))", systemImage: "trash")
                                            .fontWeight(.semibold)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                    .tint(.blue)
                                    .disabled(appState.isScanning || (appState.totalSelectedBytes == 0 && appState.safeReclaimableBytes == 0))
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                // Inaccessible locations warning
                if !appState.inaccessibleLocations.isEmpty && !appState.hasFullDiskAccess {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full Disk Access Recommended")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Granting access allows cleaning Time Machine snapshots, Mail caches, and System Data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Grant Access") {
                            appState.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
                }

                // Category List
                VStack(spacing: 16) {
                    ForEach(CandidateCategory.allCases) { category in
                        if let items = groupedCandidates[category], !items.isEmpty {
                            categoryCard(category: category, items: items)
                        }
                    }
                }
            }
            .padding(24)
        }
        .alert("Confirm Cleanup", isPresented: $showCleanConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                appState.quickCleanSafeCaches()
            }
        } message: {
            Text("Selected items will be moved to the Trash where you can review or recover them.")
        }
        .sheet(isPresented: $appState.showAICleanupView) {
            AICleanupView(appState: appState)
        }
    }

    @ViewBuilder
    private func categoryCard(category: CandidateCategory, items: [CleanupCandidate]) -> some View {
        let isExpanded = expandedCategories.contains(category)
        let categoryTotal = items.reduce(0) { $0 + $1.size }

        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: category.systemIcon)
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(category.rawValue)
                            .font(.headline)
                        Text("\(items.count) items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(category.summaryDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(categoryTotal.formattedBytes)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Button(action: {
                    if isExpanded {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))

            // Expanded Item List
            if isExpanded {
                Divider()
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { item.isSelected },
                                set: { _ in appState.toggleCandidateSelection(id: item.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)

                                    if item.isSafeByDefault {
                                        Text("Safe")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.green.opacity(0.18)))
                                            .foregroundColor(.green)
                                    }
                                }

                                Text(item.path.path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if item.id != items.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}
