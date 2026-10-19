import Foundation

/// Categories of cleanup candidates as specified in Core Experience requirements.
public enum CandidateCategory: String, CaseIterable, Identifiable, Sendable {
    case cachesAndTemp = "Caches & Temporary"
    case installersAndLogs = "Installers & Logs"
    case appDataAndLeftovers = "App Data & Leftovers"
    case browserStorage = "Browser Storage"
    case developerArtifacts = "Developer Artifacts"
    case largeFiles = "Large & Duplicate Files"
    case personalReview = "Files for Review"
    case protectedSystem = "System-Managed"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .cachesAndTemp: return "cylinder.split.1x2"
        case .installersAndLogs: return "doc.text.magnifyingglass"
        case .appDataAndLeftovers: return "app.dashed"
        case .browserStorage: return "globe"
        case .developerArtifacts: return "hammer"
        case .largeFiles: return "arrow.up.left.and.arrow.down.right"
        case .personalReview: return "person.crop.circle"
        case .protectedSystem: return "lock.shield"
        }
    }

    public var summaryDescription: String {
        switch self {
        case .cachesAndTemp:
            return "Disposable caches and temporary files that can be recreated by macOS and apps."
        case .installersAndLogs:
            return "Old .dmg files, package installers, updater caches, and rollover log files."
        case .appDataAndLeftovers:
            return "Caches and leftovers from removed apps, preferences, and container debris."
        case .browserStorage:
            return "Web caches, offline service worker stores, and cached media."
        case .developerArtifacts:
            return "Rebuildable node_modules, Xcode DerivedData, build folders, and package caches."
        case .largeFiles:
            return "Large videos, disk images, archives, and hash-verified duplicate files."
        case .personalReview:
            return "User project folders and personal files that require careful manual review."
        case .protectedSystem:
            return "System-managed files that require native tools or OS-level uninstallation."
        }
    }
}

/// Confidence level for file candidate identification.
public enum IdentificationConfidence: String, Sendable {
    case verified = "Verified"
    case high = "High"
    case heuristic = "Heuristic"
    case unknown = "Unknown / Review Needed"

    public var badgeColorName: String {
        switch self {
        case .verified: return "green"
        case .high: return "blue"
        case .heuristic: return "orange"
        case .unknown: return "gray"
        }
    }
}

/// A specific candidate item identified for storage cleanup.
public struct CleanupCandidate: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: Int64
    public let category: CandidateCategory
    public let associatedAppName: String?
    public let associatedBundleId: String?

    // Explanations for nontechnical users
    public let whatItContains: String
    public let whyItExists: String
    public let removalConsequence: String
    public let isRebuildable: Bool
    public let rebuildOrReinstallStep: String?
    public let impactsSignInsOrSettings: Bool
    public let affectsUnsyncedWork: Bool
    public let confidence: IdentificationConfidence

    // Safe defaults & selection state
    public let isSafeByDefault: Bool
    public var isSelected: Bool
    public let isProtected: Bool
    public let isDuplicate: Bool
    public let duplicateGroupHash: String?
    public let dateModified: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        size: Int64,
        category: CandidateCategory,
        associatedAppName: String? = nil,
        associatedBundleId: String? = nil,
        whatItContains: String,
        whyItExists: String,
        removalConsequence: String,
        isRebuildable: Bool,
        rebuildOrReinstallStep: String? = nil,
        impactsSignInsOrSettings: Bool = false,
        affectsUnsyncedWork: Bool = false,
        confidence: IdentificationConfidence = .high,
        isSafeByDefault: Bool = true,
        isSelected: Bool = false,
        isProtected: Bool = false,
        isDuplicate: Bool = false,
        duplicateGroupHash: String? = nil,
        dateModified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.category = category
        self.associatedAppName = associatedAppName
        self.associatedBundleId = associatedBundleId
        self.whatItContains = whatItContains
        self.whyItExists = whyItExists
        self.removalConsequence = removalConsequence
        self.isRebuildable = isRebuildable
        self.rebuildOrReinstallStep = rebuildOrReinstallStep
        self.impactsSignInsOrSettings = impactsSignInsOrSettings
        self.affectsUnsyncedWork = affectsUnsyncedWork
        self.confidence = confidence
        self.isSafeByDefault = isSafeByDefault
        self.isSelected = isSelected
        self.isProtected = isProtected
        self.isDuplicate = isDuplicate
        self.duplicateGroupHash = duplicateGroupHash
        self.dateModified = dateModified
    }
}
