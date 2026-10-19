import SwiftUI

public struct OverviewView: View {
    @ObservedObject var appState: AppState
    @State private var showSafetyGuide: Bool = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage Overview")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Analyze disk consumption, identify reclaimable files, and clean safely.")
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Button(action: {
                        showSafetyGuide = true
                    }) {
                        Label("Safety Guide", systemImage: "info.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if appState.isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(appState.scanProgressText)
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Button("Cancel") {
                                appState.cancelScan()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button(action: {
                            appState.startComprehensiveScan()
                        }) {
                            Label("Scan Mac", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }

                // Disk Capacity Visualizer
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(appState.storageOverview.volumeName)
                                .font(.headline)
                            Text("\(appState.storageOverview.fileSystemType) • \(appState.storageOverview.totalBytes.formattedBytes) Total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(appState.storageOverview.freeBytes.formattedBytes) Available")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("\(appState.storageOverview.usedBytes.formattedBytes) Used (\(Int(appState.storageOverview.usedPercentage * 100))%)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Progress Bar Gauge
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 14)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * CGFloat(appState.storageOverview.usedPercentage)), height: 14)
                        }
                    }
                    .frame(height: 14)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                // Quick Summary Cards: "What can I safely remove?"
                VStack(alignment: .leading, spacing: 14) {
                    Text("Reclaimable Storage Summary")
                        .font(.title2)
                        .fontWeight(.bold)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        CategorySummaryCard(
                            title: "Caches & Temporary",
                            icon: "cylinder.split.1x2",
                            color: .blue,
                            count: appState.candidates.filter { $0.category == .cachesAndTemp }.count,
                            bytes: appState.candidates.filter { $0.category == .cachesAndTemp }.reduce(0) { $0 + $1.size },
                            description: "Disposable application and system cache files."
                        )

                        CategorySummaryCard(
                            title: "App Leftovers & Caches",
                            icon: "app.dashed",
                            color: .purple,
                            count: appState.candidates.filter { $0.category == .appDataAndLeftovers }.count,
                            bytes: appState.candidates.filter { $0.category == .appDataAndLeftovers }.reduce(0) { $0 + $1.size },
                            description: "Orphaned containers and application cache data."
                        )

                        CategorySummaryCard(
                            title: "Developer Artifacts",
                            icon: "hammer",
                            color: .orange,
                            count: appState.candidates.filter { $0.category == .developerArtifacts }.count,
                            bytes: appState.candidates.filter { $0.category == .developerArtifacts }.reduce(0) { $0 + $1.size },
                            description: "Rebuildable node_modules, DerivedData, and builds."
                        )

                        CategorySummaryCard(
                            title: "Large & Duplicate Files",
                            icon: "arrow.up.left.and.arrow.down.right",
                            color: .teal,
                            count: appState.largeFiles.count,
                            bytes: appState.largeFiles.reduce(0) { $0 + $1.size },
                            description: "Videos, DMGs, archives, and verified duplicates."
                        )
                    }
                }

                // Full Disk Access Notice (if missing or inaccessible locations detected)
                if !appState.hasFullDiskAccess || !appState.inaccessibleLocations.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Full Disk Access Not Granted")
                                .fontWeight(.semibold)
                            Text("macOS restricts scanning and cleaning certain protected folders (e.g. Safari, Mail, Containers) without Full Disk Access. MacSweep operates safely with partial access, or you can grant permission for comprehensive system cleaning.")
                                .font(.callout)
                                .foregroundColor(.secondary)

                            Button("Grant Full Disk Access in System Settings") {
                                DiskPermissionService.shared.openFullDiskAccessSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 2)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                // Quick Action Bar
                if appState.totalSelectedBytes > 0 {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(appState.selectedCandidatesCount) Candidates Selected")
                                .fontWeight(.bold)
                            Text("\(appState.totalSelectedBytes.formattedBytes) Estimated Reclaimable Space")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            appState.presentCleanupPlan()
                        }) {
                            Text("Review Cleanup Plan")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showSafetyGuide) {
            SafetyTransparencySheet()
        }
    }
}

public struct CategorySummaryCard: View {
    public let title: String
    public let icon: String
    public let color: Color
    public let count: Int
    public let bytes: Int64
    public let description: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
                Text(bytes > 0 ? bytes.formattedBytes : "0 B")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text("\(count) items discovered")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
