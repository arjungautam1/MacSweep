import Foundation

/// A node in the hierarchical disk storage explorer tree.
public final class StorageNode: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public var size: Int64
    public var children: [StorageNode]
    public var isLoaded: Bool
    public var isExpanded: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64 = 0,
        children: [StorageNode] = [],
        isLoaded: Bool = false,
        isExpanded: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.isLoaded = isLoaded
        self.isExpanded = isExpanded
    }

    /// Helper commands for power users / terminal users
    public var cdCommand: String {
        let escaped = url.path.replacingOccurrences(of: " ", with: "\\ ")
        return "cd \(escaped)"
    }

    public var duCommand: String {
        let escaped = url.path.replacingOccurrences(of: " ", with: "\\ ")
        return "du -sh \(escaped)"
    }

    public var openCommand: String {
        let escaped = url.path.replacingOccurrences(of: " ", with: "\\ ")
        return "open \(escaped)"
    }
}
