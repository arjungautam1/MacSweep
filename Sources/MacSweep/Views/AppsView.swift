import SwiftUI
import AppKit

public struct AppsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: Int = 0 // 0: Installed Apps, 1: Orphaned Leftovers
    @State private var searchText: String = ""
    @State private var selectedAppId: UUID? = nil

    public var installedApps: [AppItem] {
        appState.apps.filter { !$0.isLeftover && (searchText.isEmpty || $0.appName.localizedCaseInsensitiveContains(searchText) || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)) }
    }

    public var leftoverApps: [AppItem] {
        appState.apps.filter { $0.isLeftover && (searchText.isEmpty || $0.appName.localizedCaseInsensitiveContains(searchText) || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Installed Apps (\(installedApps.count))").tag(0)
                    Text("Orphaned Leftovers (\(leftoverApps.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)

                Spacer()

                TextField("Filter applications...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)

                Button(action: {
                    appState.refreshApplications()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Refresh applications and leftovers")
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main Content
            if selectedTab == 0 {
                // Installed Apps List
                if installedApps.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "app.dashed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(appState.apps.isEmpty ? "No applications scanned yet." : "No matching applications.")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        if appState.apps.isEmpty {
                            Button("Scan Applications") {
                                appState.startComprehensiveScan()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }
                } else {
                    List(installedApps) { app in
                        AppDetailRowView(app: app, onAction: { action in
                            handleAppAction(app: app, action: action)
                        })
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            } else {
                // Leftovers List
                if leftoverApps.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No orphaned app leftovers detected!")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Your Library is clean of deleted application containers.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(leftoverApps) { leftover in
                        LeftoverRowView(app: leftover, onClean: {
                            cleanLeftover(leftover)
                        })
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
        }
    }

    private func handleAppAction(app: AppItem, action: String) {
        switch action {
        case "clearCache":
            var targets: [CleanupCandidate] = []
            for rel in app.relatedFiles where rel.type == .cache || rel.type == .savedState || rel.type == .log {
                let candidate = CleanupCandidate(
                    name: "\(app.appName) Caches",
                    path: rel.path,
                    size: rel.size,
                    category: .cachesAndTemp,
                    associatedAppName: app.appName,
                    whatItContains: "Application Cache",
                    whyItExists: "Generated runtime cache files.",
                    removalConsequence: "Safe to remove. App will recreate on launch.",
                    isRebuildable: true,
                    confidence: .verified,
                    isSafeByDefault: true,
                    isSelected: true
                )
                targets.append(candidate)
            }
            appState.presentCleanupPlan(for: targets)

        case "resetData":
            var targets: [CleanupCandidate] = []
            for rel in app.relatedFiles {
                let candidate = CleanupCandidate(
                    name: "\(app.appName) Local Data",
                    path: rel.path,
                    size: rel.size,
                    category: .appDataAndLeftovers,
                    associatedAppName: app.appName,
                    whatItContains: "Preferences & Application Data",
                    whyItExists: "Settings and local app files.",
                    removalConsequence: "Resets app to original install state.",
                    isRebuildable: false,
                    impactsSignInsOrSettings: true,
                    confidence: .verified,
                    isSafeByDefault: false,
                    isSelected: true
                )
                targets.append(candidate)
            }
            appState.presentCleanupPlan(for: targets)

        case "uninstall":
            // Schedule app binary plus all related files
            var targets: [CleanupCandidate] = []
            let binaryCandidate = CleanupCandidate(
                name: "\(app.appName) (.app)",
                path: app.bundleURL,
                size: app.appBinarySize,
                category: .appDataAndLeftovers,
                associatedAppName: app.appName,
                whatItContains: "Main Application Executable Bundle",
                whyItExists: "Installed application.",
                removalConsequence: "Uninstalls the application.",
                isRebuildable: true,
                rebuildOrReinstallStep: "Re-download application installer if needed.",
                confidence: .verified,
                isSafeByDefault: false,
                isSelected: true
            )
            targets.append(binaryCandidate)

            for rel in app.relatedFiles {
                let relCandidate = CleanupCandidate(
                    name: "\(app.appName) (\(rel.type.rawValue))",
                    path: rel.path,
                    size: rel.size,
                    category: .appDataAndLeftovers,
                    associatedAppName: app.appName,
                    whatItContains: rel.explanation,
                    whyItExists: "Related files for \(app.appName).",
                    removalConsequence: "Removes all associated data.",
                    isRebuildable: false,
                    impactsSignInsOrSettings: rel.affectsSettings,
                    confidence: .verified,
                    isSafeByDefault: false,
                    isSelected: true
                )
                targets.append(relCandidate)
            }
            appState.presentCleanupPlan(for: targets)

        default: break
        }
    }

    private func cleanLeftover(_ app: AppItem) {
        var targets: [CleanupCandidate] = []
        for rel in app.relatedFiles {
            let candidate = CleanupCandidate(
                name: "Leftover: \(app.appName)",
                path: rel.path,
                size: rel.size,
                category: .appDataAndLeftovers,
                associatedAppName: app.appName,
                whatItContains: "Orphaned App Container",
                whyItExists: app.leftoverEvidence ?? "Orphaned directory left behind by uninstalled app.",
                removalConsequence: "Removes old container debris.",
                isRebuildable: false,
                confidence: .high,
                isSafeByDefault: true,
                isSelected: true
            )
            targets.append(candidate)
        }
        appState.presentCleanupPlan(for: targets)
    }
}

public struct AppDetailRowView: View {
    public let app: AppItem
    public let onAction: (String) -> Void
    @State private var isExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // Native Application Icon
                AppIconView(
                    url: app.bundleURL,
                    appName: app.appName,
                    bundleIdentifier: app.bundleIdentifier,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(app.appName)
                            .font(.headline)
                        if app.isSystemApp {
                            Text("System")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                        }
                        Text("v\(app.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(app.bundleIdentifier)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.totalSize.formattedBytes)
                        .font(.headline)
                    Text("Binary: \(app.appBinarySize.formattedBytes) • Caches: \(app.cachesSize.formattedBytes)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    withAnimation { isExpanded.toggle() }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Actions & Breakdown when expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack(spacing: 12) {
                        Button("Clear Caches (\(app.cachesSize.formattedBytes))") {
                            onAction("clearCache")
                        }
                        .buttonStyle(.bordered)
                        .disabled(app.cachesSize == 0)

                        Button("Reset Local Data") {
                            onAction("resetData")
                        }
                        .buttonStyle(.bordered)

                        if !app.isSystemApp {
                            Button("Uninstall App") {
                                onAction("uninstall")
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }

                        Spacer()

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
                        }) {
                            Label("Reveal in Finder", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }

                    // Related files detail
                    if !app.relatedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Related Files Breakdown:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(app.relatedFiles) { rel in
                                HStack {
                                    Image(systemName: rel.type.systemIcon)
                                        .font(.caption2)
                                    Text("\(rel.type.rawValue): \(rel.path.lastPathComponent)")
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(rel.size.formattedBytes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

public struct LeftoverRowView: View {
    public let app: AppItem
    public let onClean: () -> Void

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AppIconView(
                url: app.bundleURL,
                appName: app.appName,
                bundleIdentifier: app.bundleIdentifier,
                fallbackSystemName: "folder.badge.gearshape",
                size: 38,
                badgeSystemName: "exclamationmark.circle.fill",
                badgeColor: .orange
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(app.appName)
                        .font(.headline)
                    Text("Leftover")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                }

                if let evidence = app.leftoverEvidence {
                    Text(evidence)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(app.bundleURL.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(app.totalSize.formattedBytes)
                .font(.headline)

            Button("Clean Leftover") {
                onClean()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }
}
