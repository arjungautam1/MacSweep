import SwiftUI
import AppKit

public struct TreemapAnalyzeView: View {
    @ObservedObject var appState: AppState
    @StateObject private var treemapService = TreemapAnalyzeService.shared
    @State private var hoveredItem: TreemapItem?
    @State private var selectedItem: TreemapItem?
    @State private var showDeleteConfirm: Bool = false

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Celestial Hero Header
            HStack(spacing: 20) {
                if let jupiterImg = AssetLoader.loadNSImage(named: "planet-static-jupiter") {
                    Image(nsImage: jupiterImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .shadow(color: .orange.opacity(0.3), radius: 10)
                } else {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Jupiter charts Analyze")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(treemapService.currentFolderTotalBytes.formattedBytes)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundColor(.orange)
                    }

                    Text(NavigationSection.analyze.poem)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                Spacer()

                Button(action: {
                    Task {
                        await treemapService.analyzeFolder(at: treemapService.currentFolderURL)
                    }
                }) {
                    Label(treemapService.isAnalyzing ? "Scanning..." : "Refresh Treemap", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(treemapService.isAnalyzing)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Breadcrumbs Bar
            HStack(spacing: 6) {
                Button(action: {
                    treemapService.navigateUp()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(treemapService.pathBreadcrumbs.count <= 1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(treemapService.pathBreadcrumbs, id: \.self) { url in
                            let isLast = url == treemapService.currentFolderURL
                            Button(action: {
                                treemapService.navigateTo(url: url)
                            }) {
                                HStack(spacing: 4) {
                                    Text(url.path == "/" ? "Macintosh HD" : url.lastPathComponent)
                                        .font(.caption)
                                        .fontWeight(isLast ? .bold : .regular)
                                        .foregroundColor(isLast ? .primary : .secondary)

                                    if !isLast {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))

            Divider()

            // Treemap Visual Area
            if treemapService.isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Calculating visual disk treemap...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if treemapService.currentItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Folder is empty")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                treemapGrid
            }

            Divider()

            // Selected Item Footer Bar
            if let item = selectedItem ?? hoveredItem ?? treemapService.currentItems.first {
                HStack(spacing: 14) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(item.kind.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(item.url.path)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Text(item.formattedSize)
                        .font(.title3)
                        .fontWeight(.bold)

                    if item.isDirectory {
                        Button("Drill Down") {
                            treemapService.navigateTo(url: item.url)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Trash") {
                        treemapService.deleteItem(item: item, useTrash: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
                .padding(14)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .onAppear {
            Task {
                await treemapService.analyzeFolder(at: treemapService.currentFolderURL)
            }
        }
    }

    // MARK: - Treemap Grid
    private var treemapGrid: some View {
        GeometryReader { geo in
            let topItems = Array(treemapService.currentItems.prefix(12))
            let total = max(1, topItems.reduce(0) { $0 + $1.size })

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ], spacing: 6) {
                ForEach(topItems) { item in
                    let fraction = Double(item.size) / Double(total)
                    let minHeight: CGFloat = max(60, min(140, CGFloat(fraction * 400)))

                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.color.opacity(hoveredItem?.id == item.id ? 0.35 : 0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(item.color.opacity(selectedItem?.id == item.id ? 0.8 : 0.4), lineWidth: selectedItem?.id == item.id ? 2 : 1)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.caption)
                                    .foregroundColor(item.color)
                                Text(item.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                Spacer()
                            }

                            Spacer()

                            HStack {
                                Text(item.formattedSize)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "%.1f%%", fraction * 100))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: minHeight)
                    .onHover { isHovered in
                        if isHovered { hoveredItem = item }
                    }
                    .onTapGesture {
                        selectedItem = item
                    }
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            if item.isDirectory {
                                treemapService.navigateTo(url: item.url)
                            } else {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                        }
                    )
                }
            }
            .padding(12)
        }
    }
}
