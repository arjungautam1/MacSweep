import Foundation
import AppKit

public final class CleanupExecutorService: @unchecked Sendable {
    public static let shared = CleanupExecutorService()

    private let fileManager = FileManager.default

    public init() {}

    /// Prepares a validated, deduplicated cleanup plan from selected candidates.
    public func prepareCleanupPlan(
        from candidates: [CleanupCandidate],
        useTrash: Bool = true,
        isDryRun: Bool = false
    ) -> CleanupPlan {
        // Use candidates marked isSelected, or all candidates if an explicit list was provided
        let selected: [CleanupCandidate]
        if candidates.contains(where: { $0.isSelected }) && candidates.contains(where: { !$0.isSelected }) {
            selected = candidates.filter { $0.isSelected }
        } else {
            selected = candidates
        }

        // Deduplicate nested paths so a parent and child are not both scheduled
        let rawURLs = selected.map { $0.path }
        let deduplicatedURLs = PathSafetyValidator.deduplicateNestedPaths(rawURLs)
        let deduplicatedPathSet = Set(deduplicatedURLs.map { $0.path })

        let finalCandidates = selected.filter { deduplicatedPathSet.contains($0.path.path) }
        let totalEstimatedBytes = finalCandidates.reduce(0) { $0 + $1.size }

        // Check for running apps that might hold open handles to these files
        let runningApps = NSWorkspace.shared.runningApplications
        var affectedApps: [NSRunningApplication] = []

        for candidate in finalCandidates {
            if let bundleId = candidate.associatedBundleId {
                if let matching = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
                    if !affectedApps.contains(matching) {
                        affectedApps.append(matching)
                    }
                }
            }
        }

        let containsSensitive = finalCandidates.contains {
            $0.impactsSignInsOrSettings || $0.affectsUnsyncedWork || $0.category == .personalReview
        }

        return CleanupPlan(
            candidates: finalCandidates,
            deduplicatedPaths: deduplicatedURLs,
            totalEstimatedReclaimableBytes: totalEstimatedBytes,
            affectedRunningApps: affectedApps,
            containsSensitiveOrProjects: containsSensitive,
            useTrash: useTrash,
            isDryRun: isDryRun
        )
    }

    /// Requests graceful termination of running applications affected by the plan.
    /// Never force-kills.
    public func requestGracefulClose(for apps: [NSRunningApplication]) -> Bool {
        for app in apps {
            app.terminate()
        }
        return true
    }

    /// Executes the validated cleanup plan and measures before/after free space.
    public func executeCleanup(plan: CleanupPlan) async -> CleanupReport {
        let preStorage = StorageOverview.current()
        var executionItems: [CleanupExecutionItem] = []

        for candidate in plan.candidates {
            if Task.isCancelled { break }
            let url = candidate.path

            // 1. Safety check
            if PathSafetyValidator.isProtectedUserPath(url) {
                executionItems.append(CleanupExecutionItem(
                    name: candidate.name,
                    path: url,
                    originalSize: candidate.size,
                    category: candidate.category,
                    status: .skippedProtected,
                    errorMessage: "Path is protected by system or user safety rules."
                ))
                continue
            }

            // 2. Pre-flight check: ensure target still exists
            guard fileManager.fileExists(atPath: url.path) else {
                executionItems.append(CleanupExecutionItem(
                    name: candidate.name,
                    path: url,
                    originalSize: candidate.size,
                    category: candidate.category,
                    status: .failed,
                    errorMessage: "Target was already removed or does not exist."
                ))
                continue
            }

            // 3. Dry-run simulation mode
            if plan.isDryRun {
                executionItems.append(CleanupExecutionItem(
                    name: candidate.name,
                    path: url,
                    originalSize: candidate.size,
                    category: candidate.category,
                    status: .simulated,
                    errorMessage: nil
                ))
                continue
            }

            // 4. Execution: Prefer Trash over permanent delete
            if plan.useTrash {
                do {
                    var resultingURL: NSURL?
                    try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
                    executionItems.append(CleanupExecutionItem(
                        name: candidate.name,
                        path: url,
                        originalSize: candidate.size,
                        category: candidate.category,
                        status: .movedToTrash,
                        trashURL: resultingURL as URL?,
                        errorMessage: nil
                    ))
                } catch {
                    executionItems.append(CleanupExecutionItem(
                        name: candidate.name,
                        path: url,
                        originalSize: candidate.size,
                        category: candidate.category,
                        status: .failed,
                        errorMessage: error.localizedDescription
                    ))
                }
            } else {
                // Permanent deletion
                do {
                    try fileManager.removeItem(at: url)
                    executionItems.append(CleanupExecutionItem(
                        name: candidate.name,
                        path: url,
                        originalSize: candidate.size,
                        category: candidate.category,
                        status: .permanentlyDeleted,
                        errorMessage: nil
                    ))
                } catch {
                    executionItems.append(CleanupExecutionItem(
                        name: candidate.name,
                        path: url,
                        originalSize: candidate.size,
                        category: candidate.category,
                        status: .failed,
                        errorMessage: error.localizedDescription
                    ))
                }
            }
        }

        // Measure post-cleanup storage
        let postStorage = StorageOverview.current()

        let report = CleanupReport(
            preCleanupAvailableBytes: preStorage.freeBytes,
            postCleanupAvailableBytes: postStorage.freeBytes,
            estimatedReclaimableBytes: plan.totalEstimatedReclaimableBytes,
            items: executionItems,
            isDryRun: plan.isDryRun
        )

        // Persist to local activity log
        logCleanupReport(report)

        return report
    }

    /// Logs cleanup activity into Application Support/MacSweep/cleanup_history.json
    /// Never stores passwords or private file content.
    private func logCleanupReport(_ report: CleanupReport) {
        let home = fileManager.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support/MacSweep")
        let historyFile = appSupport.appendingPathComponent("cleanup_history.json")

        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)

        var existingLogs: [[String: Any]] = []
        if let data = try? Data(contentsOf: historyFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            existingLogs = json
        }

        let newEntry: [String: Any] = [
            "id": report.id.uuidString,
            "date": ISO8601DateFormatter().string(from: report.date),
            "isDryRun": report.isDryRun,
            "estimatedReclaimableBytes": report.estimatedReclaimableBytes,
            "actualMeasuredReclaimedBytes": report.actualMeasuredReclaimedBytes,
            "preCleanupAvailableBytes": report.preCleanupAvailableBytes,
            "postCleanupAvailableBytes": report.postCleanupAvailableBytes,
            "successfulItemsCount": report.successfulItemsCount,
            "totalItemsCount": report.items.count,
            "items": report.items.map { [
                "name": $0.name,
                "path": $0.path.path,
                "originalSize": $0.originalSize,
                "category": $0.category.rawValue,
                "status": $0.status.rawValue,
                "errorMessage": $0.errorMessage ?? ""
            ]}
        ]

        existingLogs.insert(newEntry, at: 0)

        if let outputData = try? JSONSerialization.data(withJSONObject: Array(existingLogs.prefix(50)), options: [.prettyPrinted]) {
            try? outputData.write(to: historyFile)
        }
    }

    /// Loads history log from local storage.
    public func loadCleanupHistory() -> [CleanupReport] {
        let home = fileManager.homeDirectoryForCurrentUser
        let historyFile = home.appendingPathComponent("Library/Application Support/MacSweep/cleanup_history.json")

        guard let data = try? Data(contentsOf: historyFile),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        var reports: [CleanupReport] = []
        let dateFormatter = ISO8601DateFormatter()

        for dict in jsonArray {
            let id = UUID(uuidString: dict["id"] as? String ?? "") ?? UUID()
            let date = dateFormatter.date(from: dict["date"] as? String ?? "") ?? Date()
            let isDryRun = dict["isDryRun"] as? Bool ?? false
            let est = dict["estimatedReclaimableBytes"] as? Int64 ?? 0
            let pre = dict["preCleanupAvailableBytes"] as? Int64 ?? 0
            let post = dict["postCleanupAvailableBytes"] as? Int64 ?? 0

            var items: [CleanupExecutionItem] = []
            if let itemDicts = dict["items"] as? [[String: Any]] {
                for itemDict in itemDicts {
                    let name = itemDict["name"] as? String ?? ""
                    let pathStr = itemDict["path"] as? String ?? ""
                    let sz = itemDict["originalSize"] as? Int64 ?? 0
                    let catStr = itemDict["category"] as? String ?? ""
                    let statStr = itemDict["status"] as? String ?? ""
                    let err = itemDict["errorMessage"] as? String

                    let cat = CandidateCategory(rawValue: catStr) ?? .cachesAndTemp
                    let stat = RemovalStatus(rawValue: statStr) ?? .movedToTrash

                    items.append(CleanupExecutionItem(
                        name: name,
                        path: URL(fileURLWithPath: pathStr),
                        originalSize: sz,
                        category: cat,
                        status: stat,
                        errorMessage: err?.isEmpty == true ? nil : err
                    ))
                }
            }

            reports.append(CleanupReport(
                id: id,
                date: date,
                preCleanupAvailableBytes: pre,
                postCleanupAvailableBytes: post,
                estimatedReclaimableBytes: est,
                items: items,
                isDryRun: isDryRun
            ))
        }

        return reports
    }
}
