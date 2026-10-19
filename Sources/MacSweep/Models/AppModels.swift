import Foundation

public enum RelatedFileType: String, CaseIterable, Sendable {
    case appBinary = "Application Bundle"
    case cache = "Caches"
    case preference = "Preferences"
    case applicationSupport = "Application Support"
    case container = "Sandbox Container"
    case savedState = "Saved Application State"
    case launchAgent = "Background Launch Agent"
    case log = "Logs & Crash Reports"
    case webKitData = "WebKit & HTTP Storages"
    case leftover = "Orphaned Leftover"

    public var systemIcon: String {
        switch self {
        case .appBinary: return "app.fill"
        case .cache: return "cylinder.split.1x2"
        case .preference: return "gearshape"
        case .applicationSupport: return "folder.badge.gearshape"
        case .container: return "shippingbox"
        case .savedState: return "clock.arrow.circlepath"
        case .launchAgent: return "bolt.horizontal"
        case .log: return "doc.plaintext"
        case .webKitData: return "globe"
        case .leftover: return "exclamationmark.triangle"
        }
    }
}

public struct AppRelatedFile: Identifiable, Sendable {
    public let id: UUID
    public let path: URL
    public let type: RelatedFileType
    public let size: Int64
    public var isSelected: Bool
    public let explanation: String
    public let isRebuildable: Bool
    public let affectsSettings: Bool

    public init(
        id: UUID = UUID(),
        path: URL,
        type: RelatedFileType,
        size: Int64,
        isSelected: Bool = false,
        explanation: String,
        isRebuildable: Bool = true,
        affectsSettings: Bool = false
    ) {
        self.id = id
        self.path = path
        self.type = type
        self.size = size
        self.isSelected = isSelected
        self.explanation = explanation
        self.isRebuildable = isRebuildable
        self.affectsSettings = affectsSettings
    }
}

public struct AppItem: Identifiable, Sendable {
    public let id: UUID
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let appName: String
    public let version: String
    public let isSystemApp: Bool
    public let appBinarySize: Int64
    public var relatedFiles: [AppRelatedFile]
    public let isLeftover: Bool
    public let leftoverEvidence: String?
    public let sharedComponentWarning: String?

    public var totalSize: Int64 {
        appBinarySize + relatedFiles.reduce(0) { $0 + $1.size }
    }

    public var cachesSize: Int64 {
        relatedFiles.filter { $0.type == .cache }.reduce(0) { $0 + $1.size }
    }

    public var settingsSize: Int64 {
        relatedFiles.filter { $0.type == .preference || $0.type == .applicationSupport || $0.type == .container }.reduce(0) { $0 + $1.size }
    }

    public init(
        id: UUID = UUID(),
        bundleURL: URL,
        bundleIdentifier: String,
        appName: String,
        version: String,
        isSystemApp: Bool = false,
        appBinarySize: Int64 = 0,
        relatedFiles: [AppRelatedFile] = [],
        isLeftover: Bool = false,
        leftoverEvidence: String? = nil,
        sharedComponentWarning: String? = nil
    ) {
        self.id = id
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.version = version
        self.isSystemApp = isSystemApp
        self.appBinarySize = appBinarySize
        self.relatedFiles = relatedFiles
        self.isLeftover = isLeftover
        self.leftoverEvidence = leftoverEvidence
        self.sharedComponentWarning = sharedComponentWarning
    }
}
