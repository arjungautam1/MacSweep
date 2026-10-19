import SwiftUI

public struct MainView: View {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // Sidebar Navigation
            List(NavigationSection.allCases, selection: $appState.selectedSection) { section in
                NavigationLink(value: section) {
                    HStack(spacing: 10) {
                        Image(systemName: section.systemIcon)
                            .frame(width: 20)
                            .foregroundColor(.accentColor)
                        Text(section.rawValue)

                        Spacer()

                        // Badge Counts
                        if section == .candidates && appState.candidates.count > 0 {
                            Text("\(appState.candidates.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                        } else if section == .apps && appState.apps.count > 0 {
                            Text("\(appState.apps.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if section == .largeFiles && appState.largeFiles.count > 0 {
                            Text("\(appState.largeFiles.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("MacSweep")
            .listStyle(.sidebar)
            .frame(minWidth: 220)
        } detail: {
            // Main Content Area
            Group {
                switch appState.selectedSection {
                case .overview:
                    OverviewView(appState: appState)
                case .candidates:
                    CandidatesView(appState: appState)
                case .apps:
                    AppsView(appState: appState)
                case .browsers:
                    BrowsersView(appState: appState)
                case .developer:
                    DeveloperFilesView(appState: appState)
                case .largeFiles:
                    LargeFilesView(appState: appState)
                case .storageExplorer:
                    StorageExplorerView(appState: appState)
                case .history:
                    CleanupHistoryView(appState: appState)
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

                    // Scan / Rescan Button
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

                    // Clean Action Button
                    if appState.totalSelectedBytes > 0 {
                        Button(action: {
                            appState.presentCleanupPlan()
                        }) {
                            Label("Review & Clean (\(appState.totalSelectedBytes.formattedBytes))", systemImage: "sparkles")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $appState.showPlanSheet) {
            BatchReviewPlanSheet(appState: appState)
        }
        .sheet(isPresented: $appState.showReportSheet) {
            CleanupReportSheet(appState: appState)
        }
        .onAppear {
            appState.refreshStorageOverview()
            // Run initial scan automatically so the user gets instant insights
            appState.startComprehensiveScan()
        }
    }
}
