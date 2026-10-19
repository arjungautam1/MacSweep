import Foundation

/// Storage statistics and volume capacity details.
public struct StorageOverview: Sendable {
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let usedBytes: Int64
    public let importantAvailableBytes: Int64
    public let volumeName: String
    public let fileSystemType: String
    public let isAPFS: Bool

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var freePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }

    public init(
        totalBytes: Int64,
        freeBytes: Int64,
        usedBytes: Int64,
        importantAvailableBytes: Int64,
        volumeName: String,
        fileSystemType: String,
        isAPFS: Bool
    ) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.usedBytes = usedBytes
        self.importantAvailableBytes = importantAvailableBytes
        self.volumeName = volumeName
        self.fileSystemType = fileSystemType
        self.isAPFS = isAPFS
    }

    /// Queries the primary boot volume to get actual APFS storage metrics.
    public static func current() -> StorageOverview {
        let rootURL = URL(fileURLWithPath: "/")
        do {
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeNameKey,
                .volumeTypeNameKey
            ])

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            let importantFree = values.volumeAvailableCapacityForImportantUsage ?? free
            let used = max(0, total - free)
            let name = values.volumeName ?? "Macintosh HD"
            let fsType = values.volumeTypeName ?? "APFS"
            let isAPFS = fsType.uppercased().contains("APFS")

            return StorageOverview(
                totalBytes: total,
                freeBytes: free,
                usedBytes: used,
                importantAvailableBytes: importantFree,
                volumeName: name,
                fileSystemType: fsType,
                isAPFS: isAPFS
            )
        } catch {
            return StorageOverview(
                totalBytes: 0,
                freeBytes: 0,
                usedBytes: 0,
                importantAvailableBytes: 0,
                volumeName: "Macintosh HD",
                fileSystemType: "APFS",
                isAPFS: true
            )
        }
    }
}

/// Helper extension for formatting byte counts cleanly.
public extension Int64 {
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: self)
    }

    var formattedPreciseGB: String {
        let gb = Double(self) / 1_000_000_000.0
        return String(format: "%.2f GB", gb)
    }
}
