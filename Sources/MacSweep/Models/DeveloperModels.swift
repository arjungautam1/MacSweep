import Foundation

public enum DeveloperArtifactType: String, CaseIterable, Identifiable, Sendable {
    case nodeModules = "node_modules Dependencies"
    case webBuildOutput = "Web Framework Builds (.next, dist, out, .turbo)"
    case xcodeDerivedData = "Xcode DerivedData"
    case xcodeArchives = "Xcode Archives"
    case simulatorRuntime = "iOS / macOS Simulator Runtimes"
    case packageManagerCache = "Package Manager Caches (npm, pnpm, Bun, Yarn, Cargo)"
    case pythonCache = "Python VirtualEnvs & pycache"
    case ideExtensions = "Editor Extension Caches"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .nodeModules: return "shippingbox.fill"
        case .webBuildOutput: return "cpu"
        case .xcodeDerivedData: return "hammer.fill"
        case .xcodeArchives: return "archivebox.fill"
        case .simulatorRuntime: return "iphone.gen3"
        case .packageManagerCache: return "cylinder.split.1x2.fill"
        case .pythonCache: return "chevron.left.forwardslash.chevron.right"
        case .ideExtensions: return "puzzlepiece.fill"
        }
    }
}

public struct DeveloperCandidateItem: Identifiable, Sendable {
    public let id: UUID
    public let type: DeveloperArtifactType
    public let projectName: String
    public let projectRoot: URL?
    public let path: URL
    public let size: Int64
    public let rebuildCommand: String
    public let explanation: String
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        type: DeveloperArtifactType,
        projectName: String,
        projectRoot: URL? = nil,
        path: URL,
        size: Int64,
        rebuildCommand: String,
        explanation: String,
        isSelected: Bool = false
    ) {
        self.id = id
        self.type = type
        self.projectName = projectName
        self.projectRoot = projectRoot
        self.path = path
        self.size = size
        self.rebuildCommand = rebuildCommand
        self.explanation = explanation
        self.isSelected = isSelected
    }
}
