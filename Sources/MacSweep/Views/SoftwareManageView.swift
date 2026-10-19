import SwiftUI
import AppKit

public struct SoftwareManageView: View {
    @ObservedObject var appState: AppState
    @State private var selectedSubTab: SoftwareSubTab = .uninstaller
    @State private var searchQuery: String = ""
    @State private var quickUninstallEnabled: Bool = false
    @State private var selectedAppForDetail: AppItem?
    @State private var showConfirmUninstallAlert: Bool = false
    @State private var startupItems: [StartupItem] = []
    @State private var isLoadingStartup: Bool = false

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    public enum SoftwareSubTab: String, CaseIterable, Identifiable {
        case uninstaller = "App Uninstaller"
        case startupItems = "Startup & Launch Items"
        case updates = "Updates"

        public var id: String { rawValue }
    }

    public struct StartupItem: Identifiable {
        public let id: String
        public let name: String
        public let path: URL
        public var isEnabled: Bool
        public let type: String
    }

    private var filteredApps: [AppItem] {
        if searchQuery.isEmpty {
            return appState.apps
        }
        return appState.apps.filter {
            $0.appName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var selectedAppsCount: Int {
        appState.apps.filter { $0.isSelected }.count
    }

    private var selectedAppsReclaimableBytes: Int64 {
        appState.apps.filter { $0.isSelected }.reduce(0) { $0 + $1.totalReclaimableSize }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Celestial Hero Header
            HStack(spacing: 20) {
                if let marsImg = AssetLoader.loadNSImage(named: "planet-static-mars") {
                    Image(nsImage: marsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .shadow(color: .orange.opacity(0.3), radius: 10)
                } else {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Mars minds Software")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(appState.apps.count) Apps Detected")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundColor(.orange)
                    }

                    Text(NavigationSection.software.poem)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                Spacer()

                // Sub-tab Picker
                Picker("", selection: $selectedSubTab) {
                    ForEach(SoftwareSubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding(18)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Sub-view Content
            switch selectedSubTab {
            case .uninstaller:
                uninstallerContent
            case .startupItems:
                startupItemsContent
            case .updates:
                updatesContent
            }
        }
        .onAppear {
            loadStartupItems()
        }
        .alert("Confirm Uninstall", isPresented: $showConfirmUninstallAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall & Clean Leftovers", role: .destructive) {
                appState.uninstallSelectedApps()
            }
        } message: {
            Text("This will move the selected applications and all their associated caches, preferences, and leftovers to the Trash.")
        }
    }

    // MARK: - App Uninstaller Tab
    private var uninstallerContent: some View {
        VStack(spacing: 0) {
            // Search & Filter Toolbar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search installed apps...", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

                Spacer()

                Toggle("Quick Uninstall", isOn: $quickUninstallEnabled)
                    .toggleStyle(.switch)
                    .help("Uninstall directly from list without detailed review")

                if selectedAppsCount > 0 {
                    Button(action: {
                        showConfirmUninstallAlert = true
                    }) {
                        Label("Uninstall (\(selectedAppsCount) apps · \(selectedAppsReclaimableBytes.formattedBytes))", systemImage: "trash.fill")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))

            Divider()

            // Apps List
            List {
                ForEach(filteredApps) { app in
                    appRow(app: app)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func appRow(app: AppItem) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { _ in appState.toggleAppSelection(app.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            AppIconView(url: app.bundleURL, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.appName)
                        .font(.headline)
                    if !app.version.isEmpty {
                        Text("v\(app.version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Architecture pill
                    Text("Apple Silicon")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text("App: \(app.appSize.formattedBytes)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if app.leftoverSize > 0 {
                        Text("Leftovers: \(app.leftoverSize.formattedBytes)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(app.totalReclaimableSize.formattedBytes)
                    .font(.subheadline)
                    .fontWeight(.bold)

                if !app.relatedFiles.isEmpty {
                    Text("\(app.relatedFiles.count) leftover items")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Reveal button
            Button(action: {
                NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
            }) {
                Image(systemName: "arrow.up.forward.square")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Startup Items Tab
    private var startupItemsContent: some View {
        VStack(spacing: 0) {
            if startupItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("No Excessive Startup Launch Agents")
                        .font(.headline)
                    Text("Your system startup is lean and unencumbered.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(startupItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.title3)
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(item.path.path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(item.type)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.gray.opacity(0.18)))

                            Button("Remove") {
                                try? FileManager.default.trashItem(at: item.path, resultingItemURL: nil)
                                loadStartupItems()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Updates Tab
    private var updatesContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            VStack(spacing: 6) {
                Text("Software Updates Checker")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Supports Sparkle framework updates, Homebrew formulae, and Mac App Store.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                // Run brew update check
                Task.detached {
                    let p = Process()
                    p.launchPath = "/bin/zsh"
                    p.arguments = ["-c", "brew outdated 2>/dev/null || true"]
                    try? p.run()
                }
            }) {
                Label("Check for App Updates", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func loadStartupItems() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentsDir = home.appendingPathComponent("Library/LaunchAgents")
        var items: [StartupItem] = []

        if let contents = try? FileManager.default.contentsOfDirectory(at: launchAgentsDir, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "plist" {
                items.append(StartupItem(
                    id: url.path,
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url,
                    isEnabled: true,
                    type: "LaunchAgent"
                ))
            }
        }

        self.startupItems = items
    }
}
