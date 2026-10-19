import SwiftUI

public struct MainView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var license = LicenseService.shared

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView {
            // Sidebar Navigation
            VStack(spacing: 0) {
                // App Branding Header
                HStack(spacing: 10) {
                    AppIconView(size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("MacSweep")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("PRO")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange))
                                .foregroundColor(.white)
                        }
                        Text("Solar System Utility")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Celestial Planet Navigation List
                List(NavigationSection.allCases, selection: $appState.selectedSection) { section in
                    NavigationLink(value: section) {
                        HStack(spacing: 12) {
                            if let planetImg = AssetLoader.loadNSImage(named: section.planetStaticImageName) {
                                Image(nsImage: planetImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: section.systemIcon)
                                    .font(.body)
                                    .frame(width: 24)
                                    .foregroundColor(.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(section.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(section.planetName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Badge counts
                            if section == .clean && appState.safeReclaimableBytes > 0 {
                                Text(appState.safeReclaimableBytes.formattedBytes)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green.opacity(0.18)))
                                    .foregroundColor(.green)
                            } else if section == .software && appState.apps.count > 0 {
                                Text("\(appState.apps.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Sidebar Footer: AI Care & Pro License Quick Access
                VStack(spacing: 8) {
                    // Moon AI Tool Cleanup Button
                    Button(action: {
                        appState.showAICleanupView = true
                    }) {
                        HStack(spacing: 8) {
                            if let moonImg = AssetLoader.loadNSImage(named: "planet-static-moon") {
                                Image(nsImage: moonImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundColor(.yellow)
                            }
                            Text("AI Tool Cleanup & Care")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    // Pro License Status Card
                    Button(action: {
                        appState.showLicenseModal = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(license.isPro ? "Lifetime Pro Active" : "Trial Mode (14d)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("All Features Unlocked")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
            .frame(minWidth: 230)
        } detail: {
            // Main Content Area
            Group {
                switch appState.selectedSection {
                case .clean:
                    CleanView(appState: appState)
                case .software:
                    SoftwareManageView(appState: appState)
                case .optimize:
                    OptimizeView(appState: appState)
                case .analyze:
                    TreemapAnalyzeView(appState: appState)
                case .status:
                    StatusView(appState: appState)
                }
            }
            .navigationTitle(appState.selectedSection.rawValue)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    // Dry Run Indicator
                    Toggle(isOn: $appState.isDryRunMode) {
                        Label("Dry Run", systemImage: appState.isDryRunMode ? "shield.lefthalf.filled" : "shield")
                    }
                    .toggleStyle(.button)
                    .help("Dry run simulates scans and cleanups without deleting files.")

                    // License Pro Button
                    Button(action: {
                        appState.showLicenseModal = true
                    }) {
                        Label("Pro License", systemImage: "crown.fill")
                            .foregroundColor(.yellow)
                    }

                    // Rescan Button
                    Button(action: {
                        appState.startComprehensiveScan()
                    }) {
                        if appState.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(appState.isScanning)
                    .help("Perform a storage scan")
                }
            }
        }
        .sheet(isPresented: $appState.showAICleanupView) {
            AICleanupView(appState: appState)
        }
        .sheet(isPresented: $appState.showLicenseModal) {
            LicenseModalView()
        }
        .sheet(isPresented: $appState.showPlanSheet) {
            BatchReviewPlanSheet(appState: appState)
        }
        .sheet(isPresented: $appState.showReportSheet) {
            CleanupReportSheet(appState: appState)
        }
        .onAppear {
            appState.refreshStorageOverview()
            appState.startComprehensiveScan()
        }
    }
}
