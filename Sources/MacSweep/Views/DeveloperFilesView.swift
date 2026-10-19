import SwiftUI
import AppKit

public struct DeveloperFilesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedFilter: DeveloperArtifactType? = nil
    @State private var searchText: String = ""

    public var filteredItems: [DeveloperCandidateItem] {
        appState.developerItems.filter { item in
            let matchesFilter = selectedFilter == nil || item.type == selectedFilter
            let matchesSearch = searchText.isEmpty ||
                item.projectName.localizedCaseInsensitiveContains(searchText) ||
                item.path.path.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            VStack(spacing: 12) {
                HStack {
                    TextField("Filter developer projects or paths...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)

                    Spacer()

                    Text("\(appState.developerItems.count) build caches found (\(appState.developerItems.reduce(0) { $0 + $1.size }.formattedBytes))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All (\(appState.developerItems.count))",
                            isSelected: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )

                        ForEach(DeveloperArtifactType.allCases) { type in
                            let count = appState.developerItems.filter { $0.type == type }.count
                            if count > 0 {
                                FilterPill(
                                    title: "\(type.rawValue) (\(count))",
                                    isSelected: selectedFilter == type,
                                    action: { selectedFilter = type }
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "hammer")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No developer artifacts found.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Scans Xcode DerivedData, package caches, and project node_modules.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredItems) { item in
                    DeveloperItemRowView(item: item)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

public struct DeveloperItemRowView: View {
    public let item: DeveloperCandidateItem

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.type.systemIcon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.projectName)
                        .font(.headline)
                    Text(item.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                    Spacer()
                    Text(item.size.formattedBytes)
                        .font(.headline)
                }

                Text(item.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Rebuild Command Box
                HStack(spacing: 6) {
                    Text("Rebuild with:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(item.rebuildCommand)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)))

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.rebuildCommand, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Copy rebuild command")

                    Spacer()

                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([item.path])
                    }) {
                        Label("Reveal", systemImage: "arrow.up.forward.square")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Text(item.path.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}
