import Foundation
import AppKit

public enum RemovalStatus: String, Codable, Sendable {
    case movedToTrash = "Moved to Trash"
    case permanentlyDeleted = "Permanently Deleted"
    case simulated = "Simulated (Dry Run)"
    case skippedRunningApp = "Skipped (App Running)"
    case skippedPermission = "Skipped (Permission Denied)"
    case skippedProtected = "Skipped (System Protected)"
    case failed = "Failed"
}

public struct CleanupExecutionItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let originalSize: Int64
    public let category: CandidateCategory
    public let status: RemovalStatus
    public let trashURL: URL?
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        originalSize: Int64,
        category: CandidateCategory,
        status: RemovalStatus,
        trashURL: URL? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.originalSize = originalSize
        self.category = category
        self.status = status
        self.trashURL = trashURL
        self.errorMessage = errorMessage
    }
}

public struct CleanupPlan: Sendable {
    public let candidates: [CleanupCandidate]
    public let deduplicatedPaths: [URL]
    public let totalEstimatedReclaimableBytes: Int64
    public let affectedRunningApps: [NSRunningApplication]
    public let containsSensitiveOrProjects: Bool
    public var useTrash: Bool
    public var isDryRun: Bool

    public init(
        candidates: [CleanupCandidate],
        deduplicatedPaths: [URL],
        totalEstimatedReclaimableBytes: Int64,
        affectedRunningApps: [NSRunningApplication],
        containsSensitiveOrProjects: Bool,
        useTrash: Bool = true,
        isDryRun: Bool = false
    ) {
        self.candidates = candidates
        self.deduplicatedPaths = deduplicatedPaths
        self.totalEstimatedReclaimableBytes = totalEstimatedReclaimableBytes
        self.affectedRunningApps = affectedRunningApps
        self.containsSensitiveOrProjects = containsSensitiveOrProjects
        self.useTrash = useTrash
        self.isDryRun = isDryRun
    }
}

public struct CleanupReport: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let preCleanupAvailableBytes: Int64
    public let postCleanupAvailableBytes: Int64
    public let estimatedReclaimableBytes: Int64
    public let actualMeasuredReclaimedBytes: Int64
    public let items: [CleanupExecutionItem]
    public let isDryRun: Bool

    public var successfulItemsCount: Int {
        items.filter { $0.status == .movedToTrash || $0.status == .permanentlyDeleted || $0.status == .simulated }.count
    }

    public var skippedOrFailedCount: Int {
        items.count - successfulItemsCount
    }

    public var restoreInstructions: String {
        """
        Items were safely moved to macOS Trash.
        • To restore any item: Open the macOS Trash, locate the item, right-click, and select "Put Back".
        • Note on APFS: Space occupied by items in Trash will become free storage on your disk once you choose Finder > "Empty Trash".
        • If APFS local snapshots exist, macOS will release the physical blocks when the snapshot retention expires.
        """
    }

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        preCleanupAvailableBytes: Int64,
        postCleanupAvailableBytes: Int64,
        estimatedReclaimableBytes: Int64,
        items: [CleanupExecutionItem],
        isDryRun: Bool
    ) {
        self.id = id
        self.date = date
        self.preCleanupAvailableBytes = preCleanupAvailableBytes
        self.postCleanupAvailableBytes = postCleanupAvailableBytes
        self.estimatedReclaimableBytes = estimatedReclaimableBytes
        self.actualMeasuredReclaimedBytes = max(0, postCleanupAvailableBytes - preCleanupAvailableBytes)
        self.items = items
        self.isDryRun = isDryRun
    }
}
