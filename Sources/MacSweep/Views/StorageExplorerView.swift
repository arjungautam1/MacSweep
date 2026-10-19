import SwiftUI
import AppKit

public struct StorageExplorerView: View {
    @ObservedObject var appState: AppState
    @State private var navigationStack: [StorageNode] = []

    public var currentNode: StorageNode? {
        navigationStack.last ?? appState.storageRootNode
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Breadcrumbs Bar
            HStack(spacing: 6) {
                Button(action: {
                    navigationStack.removeAll()
                }) {
                    Image(systemName: "house.fill")
                }
                .buttonStyle(.plain)

                ForEach(0..<navigationStack.count, id: \.self) { idx in
                    Text("/")
                        .foregroundColor(.secondary)
                    Button(action: {
                        navigationStack = Array(navigationStack.prefix(idx + 1))
                    }) {
                        Text(navigationStack[idx].name)
                            .fontWeight(idx == navigationStack.count - 1 ? .bold : .regular)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if let current = currentNode {
                    Text("\(current.size.formattedBytes) total")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Contents List
            if let node = currentNode {
                if node.children.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No subdirectories or file scan pending.")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Button("Scan Disk Tree") {
                            appState.startComprehensiveScan()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(node.children) { child in
                        StorageNodeRowView(
                            node: child,
                            parentTotalSize: max(1, node.size),
                            onDigIn: {
                                if child.isDirectory {
                                    // If not loaded, populate children
                                    if child.children.isEmpty {
                                        let updated = DiskScannerService.shared.buildStorageTree(at: child.url, maxDepth: 1)
                                        child.children = updated.children
                                    }
                                    navigationStack.append(child)
                                }
                            }
                        )
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Indexing user storage...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

public struct StorageNodeRowView: View {
    public let node: StorageNode
    public let parentTotalSize: Int64
    public let onDigIn: () -> Void

    public var percentageOfParent: Double {
        Double(node.size) / Double(parentTotalSize)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .font(.title2)
                .foregroundColor(node.isDirectory ? .blue : .secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.name)
                        .font(.headline)
                    Spacer()
                    Text(node.size.formattedBytes)
                        .font(.headline)
                }

                // Storage usage relative bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: max(2, geo.size.width * CGFloat(percentageOfParent)), height: 6)
                    }
                }
                .frame(height: 6)

                // Power user commands (requested in user audio!)
                HStack(spacing: 10) {
                    Text(node.url.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    // Copy cd command
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(node.cdCommand, forType: .string)
                    }) {
                        Label("cd", systemImage: "terminal")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Copy 'cd' command to clipboard")

                    // Copy du command
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(node.duCommand, forType: .string)
                    }) {
                        Label("du", systemImage: "chart.bar")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Copy 'du -sh' command to clipboard")

                    // Reveal in Finder
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([node.url])
                    }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")

                    if node.isDirectory {
                        Button(action: onDigIn) {
                            Text("Dig In →")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
