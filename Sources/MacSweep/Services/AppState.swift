import Foundation
import SwiftUI
import Combine

public enum NavigationSection: String, CaseIterable, Identifiable, Sendable {
    case clean = "Clean"
    case software = "Software"
    case optimize = "Optimize"
    case analyze = "Analyze"
    case status = "Status"

    public var id: String { rawValue }

    public var planetName: String {
        switch self {
        case .clean: return "Earth"
        case .software: return "Mars"
        case .optimize: return "Mercury"
        case .analyze: return "Jupiter"
        case .status: return "Sun"
        }
    }

    public var planetStaticImageName: String {
        switch self {
        case .clean: return "planet-static-earth"
        case .software: return "planet-static-mars"
        case .optimize: return "planet-static-mercury"
        case .analyze: return "planet-static-jupiter"
        case .status: return "planet-static-sun"
        }
    }

    public var poem: String {
        switch self {
        case .clean:
            return "Mountain rain washes old dust away.\nThe ebbing tide leaves all things new."
        case .software:
            return "Red sands bury old traces.\nA great wind opens the road."
        case .optimize:
            return "Closest to the sun, swiftest in flight.\nThe lightest touch, and nothing stalls."
        case .analyze:
            return "The widest eye of all.\nNo grain too small to find."
        case .status:
            return "The light that never sleeps.\nEvery pulse shows in its glow."
        }
    }

    public var systemIcon: String {
        switch self {
        case .clean: return "globe.americas.fill"
        case .software: return "shippingbox.fill"
        case .optimize: return "bolt.fill"
        case .analyze: return "chart.pie.fill"
        case .status: return "sun.max.fill"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedSection: NavigationSection = .clean
    @Published public var showAICleanupView: Bool = false
    @Published public var showLicenseModal: Bool = false
    @Published public var isCleanScreenActive: Bool = false

    // Disk Metrics
    @Published public var storageOverview: StorageOverview = StorageOverview.current()

    // Scan State
    @Published public var isScanning: Bool = false
    @Published public var scanProgressText: String = "Ready to scan"
    @Published public var inaccessibleLocations: [(url: URL, reason: String)] = []

    // Detected Categories
    @Published public var candidates: [CleanupCandidate] = []
    @Published public var apps: [AppItem] = []
    @Published public var browserItems: [BrowserItem] = []
    @Published public var developerItems: [DeveloperCandidateItem] = []
    @Published public var largeFiles: [LargeFileItem] = []
    @Published public var storageRootNode: StorageNode?

    // History
    @Published public var cleanupHistory: [CleanupReport] = []

    // Options & Sheets
    @Published public var preservePasswordsAndSignIns: Bool = true
    @Published public var isDryRunMode: Bool = false
    @Published public var showPlanSheet: Bool = false
    @Published public var showReportSheet: Bool = false
    @Published public var currentPlan: CleanupPlan?
    @Published public var currentReport: CleanupReport?
    @Published public var hasFullDiskAccess: Bool = false

    private var scanTask: Task<Void, Never>?

    public init() {
        self.cleanupHistory = CleanupExecutorService.shared.loadCleanupHistory()
        self.hasFullDiskAccess = DiskPermissionService.shared.checkAccess()
    }

    public func refreshPermissions() {
        self.hasFullDiskAccess = DiskPermissionService.shared.checkAccess()
    }

    public func openFullDiskAccessSettings() {
        DiskPermissionService.shared.openFullDiskAccessSettings()
    }

    // Computed totals
    public var totalSelectedBytes: Int64 {
        candidates.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public var selectedCandidatesCount: Int {
        candidates.filter { $0.isSelected }.count
    }

    public var safeReclaimableBytes: Int64 {
        candidates.filter { $0.isSafeByDefault }.reduce(0) { $0 + $1.size }
    }

    public var safeCandidatesCount: Int {
        candidates.filter { $0.isSafeByDefault }.count
    }

    // Refresh disk overview
    public func refreshStorageOverview() {
        self.storageOverview = StorageOverview.current()
    }

    public func quickCleanSafeCaches() {
        let safeTargets = candidates.filter { $0.isSafeByDefault }.map { candidate -> CleanupCandidate in
            var c = candidate
            c.isSelected = true
            return c
        }
        guard !safeTargets.isEmpty else {
            startComprehensiveScan()
            return
        }
        let plan = CleanupExecutorService.shared.prepareCleanupPlan(from: safeTargets, useTrash: true, isDryRun: isDryRunMode)
        executePlan(plan)
    }

    // Start comprehensive scan
    public func startComprehensiveScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgressText = "Starting system storage scan..."
        inaccessibleLocations.removeAll()
        candidates.removeAll()

        scanTask = Task {
            // 1. Storage overview
            let overview = StorageOverview.current()
            await MainActor.run {
                self.storageOverview = overview
                self.scanProgressText = "Scanning standard caches and installer downloads..."
            }

            // 2. Scan standard caches and logs
            await DiskScannerService.shared.scanStandardCachesAndLogs(
                onItemDiscovered: { candidate in
                    Task { @MainActor in
                        self.candidates.append(candidate)
                    }
                },
                onInaccessibleLocation: { url, reason in
                    Task { @MainActor in
                        self.inaccessibleLocations.append((url, reason))
                    }
                }
            )

            // 3. Scan applications and leftovers
            await MainActor.run {
                self.scanProgressText = "Scanning installed applications and leftovers..."
            }
            let scannedApps = AppAnalyzerService.shared.scanInstalledApplications()
            await MainActor.run {
                self.apps = scannedApps
                // Convert app caches and leftovers to candidates
                for app in scannedApps {
                    for rel in app.relatedFiles where rel.type == .cache || rel.type == .savedState || rel.type == .log {
                        let candidate = CleanupCandidate(
                            name: "\(app.appName) (\(rel.type.rawValue))",
                            path: rel.path,
                            size: rel.size,
                            category: .appDataAndLeftovers,
                            associatedAppName: app.appName,
                            associatedBundleId: app.bundleIdentifier,
                            whatItContains: rel.explanation,
                            whyItExists: "Generated by \(app.appName) during operation.",
                            removalConsequence: "Safe to remove. Caches will be recreated.",
                            isRebuildable: rel.isRebuildable,
                            confidence: .verified,
                            isSafeByDefault: true,
                            isSelected: false
                        )
                        self.candidates.append(candidate)
                    }
                }
            }

            // 4. Scan browsers
            await MainActor.run {
                self.scanProgressText = "Analyzing browser profiles (Chrome, Edge, Arc, Brave)..."
            }
            let browsers = BrowserAnalyzerService.shared.scanBrowsers(preservePasswordsAndSignIns: self.preservePasswordsAndSignIns)
            await MainActor.run {
                self.browserItems = browsers
                for bItem in browsers {
                    let candidate = CleanupCandidate(
                        name: "\(bItem.browser.rawValue) - \(bItem.storageType.rawValue)",
                        path: bItem.path,
                        size: bItem.size,
                        category: .browserStorage,
                        associatedAppName: bItem.browser.rawValue,
                        whatItContains: bItem.storageType.rawValue,
                        whyItExists: "Created by \(bItem.browser.rawValue) profile '\(bItem.profileName)'.",
                        removalConsequence: bItem.storageType.riskDescription,
                        isRebuildable: bItem.storageType.isSafeByDefault,
                        confidence: .verified,
                        isSafeByDefault: bItem.storageType.isSafeByDefault,
                        isSelected: bItem.isSelected
                    )
                    self.candidates.append(candidate)
                }
            }

            // 5. Scan developer files
            await MainActor.run {
                self.scanProgressText = "Scanning developer folders (DerivedData, node_modules, build outputs)..."
            }
            let dev = DeveloperAnalyzerService.shared.scanDeveloperArtifacts()
            await MainActor.run {
                self.developerItems = dev
                for dItem in dev {
                    let candidate = CleanupCandidate(
                        name: "\(dItem.projectName) (\(dItem.type.rawValue))",
                        path: dItem.path,
                        size: dItem.size,
                        category: .developerArtifacts,
                        associatedAppName: dItem.projectName,
                        whatItContains: dItem.explanation,
                        whyItExists: "Built or cached during project development.",
                        removalConsequence: "Removes generated build. Can be recreated with: \(dItem.rebuildCommand)",
                        isRebuildable: true,
                        rebuildOrReinstallStep: dItem.rebuildCommand,
                        confidence: .verified,
                        isSafeByDefault: dItem.type == .xcodeDerivedData || dItem.type == .packageManagerCache,
                        isSelected: dItem.isSelected
                    )
                    self.candidates.append(candidate)
                }
            }

            // 6. Scan large files & duplicates
            await MainActor.run {
                self.scanProgressText = "Scanning large files (>50MB) and identifying duplicates..."
            }
            let large = LargeFileAnalyzerService.shared.scanLargeFiles(minimumSizeBytes: 50_000_000)
            await MainActor.run {
                self.largeFiles = large
            }

            // 7. Build storage explorer tree (User home root)
            await MainActor.run {
                self.scanProgressText = "Indexing storage explorer tree..."
            }
            let home = FileManager.default.homeDirectoryForCurrentUser
            let rootNode = DiskScannerService.shared.buildStorageTree(at: home, maxDepth: 2)

            await MainActor.run {
                self.storageRootNode = rootNode
                self.isScanning = false
                self.scanProgressText = "Scan completed. Found \(self.candidates.count) candidates."
                StorageNotificationService.shared.checkForLargeFiles()
            }
        }
    }

    public func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        scanProgressText = "Scan cancelled."
    }

    public func selectAllSafeCandidates() {
        for i in 0..<candidates.count {
            if candidates[i].isSafeByDefault {
                candidates[i].isSelected = true
            }
        }
    }

    public func deselectAllCandidates() {
        for i in 0..<candidates.count {
            candidates[i].isSelected = false
        }
    }

    public func toggleCandidateSelection(id: UUID) {
        if let idx = candidates.firstIndex(where: { $0.id == id }) {
            candidates[idx].isSelected.toggle()
        }
    }

    public func toggleAppSelection(_ id: UUID) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].isSelected.toggle()
        }
    }

    public func uninstallSelectedApps() {
        let targets = apps.filter { $0.isSelected }
        for app in targets {
            try? FileManager.default.trashItem(at: app.bundleURL, resultingItemURL: nil)
            for file in app.relatedFiles {
                try? FileManager.default.trashItem(at: file.path, resultingItemURL: nil)
            }
        }
        startComprehensiveScan()
    }

    // Review Plan
    public func presentCleanupPlan(for specificCandidates: [CleanupCandidate]? = nil) {
        let targets: [CleanupCandidate]
        if let specific = specificCandidates, !specific.isEmpty {
            targets = specific
        } else {
            targets = candidates.filter { $0.isSelected }
        }

        guard !targets.isEmpty else { return }

        let plan = CleanupExecutorService.shared.prepareCleanupPlan(
            from: targets,
            useTrash: true,
            isDryRun: isDryRunMode
        )
        self.currentPlan = plan
        self.showPlanSheet = true
    }

    // Execute Cleanup
    public func executeCurrentPlan() {
        guard let plan = currentPlan else { return }
        executePlan(plan)
    }

    // Rescan only applications and leftovers
    public func refreshApplications() {
        Task {
            let scannedApps = AppAnalyzerService.shared.scanInstalledApplications()
            await MainActor.run {
                self.apps = scannedApps
            }
        }
    }

    public func executePlan(_ plan: CleanupPlan) {
        self.currentPlan = plan
        self.showPlanSheet = false

        Task {
            let report = await CleanupExecutorService.shared.executeCleanup(plan: plan)
            await MainActor.run {
                self.currentReport = report
                self.cleanupHistory.insert(report, at: 0)
                self.showReportSheet = true
                self.refreshStorageOverview()

                // Only prune in-memory models if actual removal took place (not a dry run simulation)
                if !report.isDryRun {
                    let removedPaths = Set(report.items.filter {
                        $0.status == .movedToTrash || $0.status == .permanentlyDeleted
                    }.map { $0.path.path })

                    func isPathRemoved(_ path: String) -> Bool {
                        if removedPaths.contains(path) { return true }
                        for removed in removedPaths {
                            let prefix = removed.hasSuffix("/") ? removed : removed + "/"
                            if path.hasPrefix(prefix) { return true }
                        }
                        return false
                    }

                    // 1. Refresh candidates by removing successfully cleaned ones
                    self.candidates.removeAll { isPathRemoved($0.path.path) }

                    // 2. Refresh apps and orphaned leftovers
                    self.apps = self.apps.compactMap { app in
                        // If app bundle was removed, remove the app
                        if isPathRemoved(app.bundleURL.path) {
                            return nil
                        }
                        // If orphaned leftover and any of its files or bundle was removed, remove it
                        if app.isLeftover {
                            if app.relatedFiles.contains(where: { isPathRemoved($0.path.path) }) || isPathRemoved(app.bundleURL.path) {
                                return nil
                            }
                        }
                        // For installed apps, remove any related files that were cleaned
                        var updated = app
                        updated.relatedFiles = app.relatedFiles.filter { !isPathRemoved($0.path.path) }
                        return updated
                    }

                    // 3. Refresh developer items
                    self.developerItems.removeAll { isPathRemoved($0.path.path) }

                    // 4. Refresh browser items
                    self.browserItems.removeAll { isPathRemoved($0.path.path) }

                    // 5. Refresh large files
                    self.largeFiles.removeAll { isPathRemoved($0.path.path) }
                }

                self.refreshPermissions()
            }
        }
    }
}
