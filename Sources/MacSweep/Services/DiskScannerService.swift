import Foundation

public final class DiskScannerService: @unchecked Sendable {
    public static let shared = DiskScannerService()

    private let fileManager = FileManager.default

    public init() {}

    /// Calculates the allocated disk size for a single file or directory on APFS.
    public func allocatedSize(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if !isDir.boolValue {
            do {
                let values = try url.resourceValues(forKeys: [.fileAllocatedSizeKey, .fileSizeKey])
                return Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
            } catch {
                return 0
            }
        }

        // For directories, enumerate contents recursively
        var totalAllocated: Int64 = 0
        let resourceKeys: Set<URLResourceKey> = [.fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: resourceKeys)
                if values.isRegularFile == true {
                    let size = Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
                    totalAllocated += size
                }
            } catch {
                continue
            }
        }
        return totalAllocated
    }

    /// Recursively builds a ranked `StorageNode` tree for storage exploration.
    public func buildStorageTree(at rootURL: URL, maxDepth: Int = 2, currentDepth: Int = 0) -> StorageNode {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDir) else {
            return StorageNode(url: rootURL, name: rootURL.lastPathComponent, isDirectory: false, size: 0)
        }

        if !isDir.boolValue {
            let size = allocatedSize(of: rootURL)
            return StorageNode(url: rootURL, name: rootURL.lastPathComponent, isDirectory: false, size: size, isLoaded: true)
        }

        let node = StorageNode(
            url: rootURL,
            name: rootURL.lastPathComponent.isEmpty ? rootURL.path : rootURL.lastPathComponent,
            isDirectory: true
        )

        guard currentDepth < maxDepth else {
            node.size = allocatedSize(of: rootURL)
            node.isLoaded = false
            return node
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            )

            var childNodes: [StorageNode] = []
            var totalSize: Int64 = 0

            for itemURL in contents {
                let child = buildStorageTree(at: itemURL, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                totalSize += child.size
                childNodes.append(child)
            }

            // Sort children descending by size (highest consumers first)
            childNodes.sort { $0.size > $1.size }
            node.children = childNodes
            node.size = totalSize
            node.isLoaded = true
        } catch {
            node.size = allocatedSize(of: rootURL)
            node.isLoaded = true
        }

        return node
    }

    /// Scans standard macOS caches, logs, and temporary locations.
    public func scanStandardCachesAndLogs(
        onItemDiscovered: @escaping @Sendable (CleanupCandidate) -> Void,
        onInaccessibleLocation: @escaping @Sendable (URL, String) -> Void
    ) async {
        let home = fileManager.homeDirectoryForCurrentUser

        let cacheTargets: [(URL, CandidateCategory, String, String, String, String)] = [
            (
                home.appendingPathComponent("Library/Caches"),
                .cachesAndTemp,
                "User Application Caches",
                "Contains cached data from user applications to speed up recurring operations.",
                "Safe to remove. Apps will automatically rebuild cache files as needed.",
                "Recreated automatically on next app launch."
            ),
            (
                home.appendingPathComponent("Library/Logs"),
                .installersAndLogs,
                "Application & Diagnostic Logs",
                "Historical event and diagnostic logs recorded by applications.",
                "Safe to remove. New diagnostic logs will be created as apps run.",
                "Recreated automatically as logs accumulate."
            ),
            (
                home.appendingPathComponent("Downloads"),
                .installersAndLogs,
                "Downloaded Disk Images (.dmg) & Installers (.pkg)",
                "Installation disk images and installer packages downloaded from the internet.",
                "Safe if apps are already installed. You can re-download them from the original vendor if needed.",
                "Download again from the software vendor if ever needed."
            ),
            (
                URL(fileURLWithPath: "/Library/Caches"),
                .cachesAndTemp,
                "System Shared Caches",
                "System-wide cached data shared across accounts.",
                "Rebuilt automatically by system daemons.",
                "Rebuilt automatically."
            ),
            (
                URL(fileURLWithPath: "/private/var/log"),
                .installersAndLogs,
                "System Rollover Logs",
                "Archived system diagnostic log files.",
                "Safe to clear old rotated logs. Fresh logs continue to be written.",
                "Archived logs are not needed for normal operation."
            )
        ]

        for target in cacheTargets {
            if Task.isCancelled { break }
            let url = target.0

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if url.lastPathComponent == "Downloads" {
                // For downloads, identify old .dmg, .pkg, .iso, .zip files
                do {
                    let items = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .fileAllocatedSizeKey])
                    for item in items {
                        let ext = item.pathExtension.lowercased()
                        if ["dmg", "pkg", "iso"].contains(ext) {
                            let size = allocatedSize(of: item)
                            if size > 10_000_000 { // 10MB+
                                let candidate = CleanupCandidate(
                                    name: item.lastPathComponent,
                                    path: item,
                                    size: size,
                                    category: .installersAndLogs,
                                    whatItContains: "Installer disk image or setup package.",
                                    whyItExists: "Downloaded when installing \(item.deletingPathExtension().lastPathComponent).",
                                    removalConsequence: "Removes installer. The installed application remains intact.",
                                    isRebuildable: true,
                                    rebuildOrReinstallStep: "Re-download installer from the developer's website if needed.",
                                    confidence: .verified,
                                    isSafeByDefault: true,
                                    isSelected: false
                                )
                                onItemDiscovered(candidate)
                            }
                        }
                    }
                } catch {
                    onInaccessibleLocation(url, error.localizedDescription)
                }
                continue
            }

            // For Caches and Logs folders, enumerate top-level child bundles/directories
            do {
                let items = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
                for item in items {
                    if Task.isCancelled { break }
                    let itemName = item.lastPathComponent
                    // Exclude internal Apple system daemons and caches (e.g., com.apple.InferenceProviderService)
                    // These belong to macOS internal daemons and shouldn't be purged by user cleaners.
                    if itemName.hasPrefix("com.apple.") {
                        continue
                    }
                    let size = allocatedSize(of: item)
                    if size > 5_000_000 { // > 5MB to avoid noise
                        let candidate = CleanupCandidate(
                            name: itemName,
                            path: item,
                            size: size,
                            category: target.1,
                            associatedAppName: itemName.replacingOccurrences(of: "com.", with: ""),
                            associatedBundleId: itemName,
                            whatItContains: target.3,
                            whyItExists: target.3,
                            removalConsequence: target.4,
                            isRebuildable: true,
                            rebuildOrReinstallStep: target.5,
                            confidence: .high,
                            isSafeByDefault: target.1 == .cachesAndTemp,
                            isSelected: false
                        )
                        onItemDiscovered(candidate)
                    }
                }
            } catch {
                onInaccessibleLocation(url, error.localizedDescription)
            }
        }
    }
}
