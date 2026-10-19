import SwiftUI
import AppKit

public struct CandidatesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedCategoryFilter: CandidateCategory? = nil
    @State private var searchText: String = ""
    @State private var showSafetyGuide: Bool = false

    public var filteredCandidates: [CleanupCandidate] {
        appState.candidates.filter { candidate in
            let matchesCategory = selectedCategoryFilter == nil || candidate.category == selectedCategoryFilter
            let matchesSearch = searchText.isEmpty ||
                candidate.name.localizedCaseInsensitiveContains(searchText) ||
                candidate.path.path.localizedCaseInsensitiveContains(searchText) ||
                (candidate.associatedAppName?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesCategory && matchesSearch
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Safety & Transparency Info Banner
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacSweep Safety Guarantee")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("Personal documents, desktop files, git repos, and keychain passwords are never touched.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { showSafetyGuide = true }) {
                    Label("What Gets Deleted & Why?", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.08))

            Divider()

            // Filter Bar
            VStack(spacing: 12) {
                HStack {
                    TextField("Search candidates or paths...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)

                    Spacer()

                    Button("Select Safe Defaults") {
                        appState.selectAllSafeCandidates()
                    }
                    .buttonStyle(.bordered)

                    Button("Deselect All") {
                        appState.deselectAllCandidates()
                    }
                    .buttonStyle(.bordered)
                }

                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All (\(appState.candidates.count))",
                            isSelected: selectedCategoryFilter == nil,
                            action: { selectedCategoryFilter = nil }
                        )

                        ForEach(CandidateCategory.allCases) { cat in
                            let count = appState.candidates.filter { $0.category == cat }.count
                            if count > 0 {
                                FilterPill(
                                    title: "\(cat.rawValue) (\(count))",
                                    isSelected: selectedCategoryFilter == cat,
                                    action: { selectedCategoryFilter = cat }
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // List of Candidates
            if filteredCandidates.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(appState.candidates.isEmpty ? "No candidates scanned yet." : "No matching candidates found.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    if appState.candidates.isEmpty {
                        Button("Start Scan") {
                            appState.startComprehensiveScan()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredCandidates) { candidate in
                        CandidateRowView(
                            candidate: candidate,
                            onToggle: {
                                appState.toggleCandidateSelection(id: candidate.id)
                            }
                        )
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            // Bottom Action Footer
            if appState.totalSelectedBytes > 0 {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(appState.selectedCandidatesCount) items selected for cleaning")
                            .fontWeight(.bold)
                        Text("Estimated recoverable space: \(appState.totalSelectedBytes.formattedBytes)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        appState.presentCleanupPlan()
                    }) {
                        Text("Review Cleanup Plan (\(appState.totalSelectedBytes.formattedBytes))")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(16)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .sheet(isPresented: $showSafetyGuide) {
            SafetyTransparencySheet()
        }
    }
}

public struct FilterPill: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

public struct CandidateRowView: View {
    public let candidate: CleanupCandidate
    public let onToggle: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Toggle("", isOn: Binding(
                    get: { candidate.isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(.top, 2)

                // Category Icon
                Image(systemName: candidate.category.systemIcon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(candidate.name)
                            .font(.headline)

                        // Safety Badge
                        if candidate.isSafeByDefault {
                            Text("Safe")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.2)))
                                .foregroundColor(.green)
                        } else {
                            Text("Review Advised")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.2)))
                                .foregroundColor(.orange)
                        }

                        // Confidence Badge
                        Text(candidate.confidence.rawValue.capitalized)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.18)))
                            .foregroundColor(.secondary)

                        if candidate.isRebuildable {
                            Text("Rebuildable")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                .foregroundColor(.blue)
                        }

                        Spacer()

                        Text(candidate.size.formattedBytes)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Path link
                    HStack(spacing: 4) {
                        Text(candidate.path.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([candidate.path])
                        }) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }

                    // Detailed Explanations
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Contains: \(candidate.whatItContains)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Why it exists: \(candidate.whyItExists)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Removal Effect: \(candidate.removalConsequence)")
                            .font(.caption)
                            .foregroundColor(candidate.impactsSignInsOrSettings ? .orange : .secondary)

                        if let rebuild = candidate.rebuildOrReinstallStep {
                            Text("• Rebuilding: \(rebuild)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }

                        // Sensitive Flags
                        if candidate.impactsSignInsOrSettings {
                            Label("Affects settings or sign-ins", systemImage: "key.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        if candidate.affectsUnsyncedWork {
                            Label("May affect unsynced offline data", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
