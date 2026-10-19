import SwiftUI
import AppKit

public struct LargeFilesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedKind: LargeFileKind? = nil
    @State private var onlyDuplicates: Bool = false
    @State private var searchText: String = ""

    public var filteredFiles: [LargeFileItem] {
        appState.largeFiles.filter { file in
            let matchesKind = selectedKind == nil || file.kind == selectedKind
            let matchesDuplicates = !onlyDuplicates || file.isDuplicate
            let matchesSearch = searchText.isEmpty ||
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.path.path.localizedCaseInsensitiveContains(searchText)
            return matchesKind && matchesDuplicates && matchesSearch
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            VStack(spacing: 12) {
                HStack {
                    TextField("Filter large files...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)

                    Spacer()

                    Toggle("Only Verified Duplicates", isOn: $onlyDuplicates)
                        .toggleStyle(.checkbox)

                    Text("\(filteredFiles.count) files (\(filteredFiles.reduce(0) { $0 + $1.size }.formattedBytes))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All Large Files (\(appState.largeFiles.count))",
                            isSelected: selectedKind == nil,
                            action: { selectedKind = nil }
                        )

                        ForEach(LargeFileKind.allCases, id: \.self) { kind in
                            let count = appState.largeFiles.filter { $0.kind == kind }.count
                            if count > 0 {
                                FilterPill(
                                    title: "\(kind.rawValue) (\(count))",
                                    isSelected: selectedKind == kind,
                                    action: { selectedKind = kind }
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
            if filteredFiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(onlyDuplicates ? "No duplicate files found." : "No large files found.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Scans Downloads, Movies, Desktop, and Documents for files > 50MB.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredFiles) { file in
                    LargeFileRowView(file: file)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

public struct LargeFileRowView: View {
    public let file: LargeFileItem

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: file.kind.systemIcon)
                .font(.title2)
                .foregroundColor(.teal)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(file.name)
                        .font(.headline)

                    if file.isDuplicate {
                        Text("Verified Duplicate (SHA-256)")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }

                    Spacer()

                    Text(file.size.formattedBytes)
                        .font(.headline)
                }

                HStack(spacing: 8) {
                    Text(file.path.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([file.path])
                    }) {
                        Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSWorkspace.shared.open(file.path)
                    }) {
                        Label("Open", systemImage: "eye")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
