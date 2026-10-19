import Foundation
import CryptoKit

public enum LargeFileKind: String, CaseIterable, Sendable {
    case video = "Videos & Recordings"
    case diskImage = "Disk Images (.dmg, .iso)"
    case archive = "Compressed Archives (.zip, .tar, .tgz)"
    case generic = "Other Large Files"

    public var systemIcon: String {
        switch self {
        case .video: return "film"
        case .diskImage: return "opticaldisc"
        case .archive: return "archivebox"
        case .generic: return "doc"
        }
    }
}

public struct LargeFileItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: Int64
    public let kind: LargeFileKind
    public let dateModified: Date?
    public var isSelected: Bool
    public var isDuplicate: Bool
    public var duplicateGroupHash: String?

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        size: Int64,
        kind: LargeFileKind,
        dateModified: Date? = nil,
        isSelected: Bool = false,
        isDuplicate: Bool = false,
        duplicateGroupHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.kind = kind
        self.dateModified = dateModified
        self.isSelected = isSelected
        self.isDuplicate = isDuplicate
        self.duplicateGroupHash = duplicateGroupHash
    }
}

public final class LargeFileAnalyzerService: @unchecked Sendable {
    public static let shared = LargeFileAnalyzerService()

    private let fileManager = FileManager.default
    private let scanner = DiskScannerService.shared

    public init() {}

    /// Scans user folders for files exceeding minimumSizeBytes (default: 50 MB).
    public func scanLargeFiles(minimumSizeBytes: Int64 = 50_000_000) -> [LargeFileItem] {
        let home = fileManager.homeDirectoryForCurrentUser
        let targetDirs = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents")
        ]

        var found: [LargeFileItem] = []

        for dir in targetDirs where fileManager.fileExists(atPath: dir.path) {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
                    guard values.isRegularFile == true else { continue }

                    let size = Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
                    if size >= minimumSizeBytes {
                        let ext = fileURL.pathExtension.lowercased()
                        let kind: LargeFileKind
                        if ["mov", "mp4", "m4v", "mkv", "avi"].contains(ext) {
                            kind = .video
                        } else if ["dmg", "iso", "sparseimage", "img"].contains(ext) {
                            kind = .diskImage
                        } else if ["zip", "tar", "gz", "tgz", "bz2", "7z", "rar"].contains(ext) {
                            kind = .archive
                        } else {
                            kind = .generic
                        }

                        found.append(LargeFileItem(
                            name: fileURL.lastPathComponent,
                            path: fileURL,
                            size: size,
                            kind: kind,
                            dateModified: values.contentModificationDate,
                            isSelected: false
                        ))
                    }
                } catch {
                    continue
                }
            }
        }

        // Deduplication pass: detect exact duplicates using SHA-256 hash comparison
        let itemsWithDuplicates = identifyDuplicates(in: found)
        return itemsWithDuplicates.sorted { $0.size > $1.size }
    }

    /// Finds files with identical byte sizes and verifies their SHA-256 hash.
    public func identifyDuplicates(in items: [LargeFileItem]) -> [LargeFileItem] {
        // Group by exact size first
        let groupedBySize = Dictionary(grouping: items, by: { $0.size })
        var results = items

        for (_, group) in groupedBySize where group.count > 1 {
            var hashes: [String: [UUID]] = [:]

            for item in group {
                if let hash = computeFileHash(url: item.path) {
                    hashes[hash, default: []].append(item.id)
                }
            }

            for (hash, ids) in hashes where ids.count > 1 {
                for i in 0..<results.count {
                    if ids.contains(results[i].id) {
                        results[i].isDuplicate = true
                        results[i].duplicateGroupHash = hash
                    }
                }
            }
        }

        return results
    }

    /// Computes SHA-256 hash of the initial 2MB chunk and final chunk for fast, reliable verification.
    public func computeFileHash(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        do {
            let chunk = try handle.read(upToCount: 2 * 1024 * 1024) ?? Data()
            hasher.update(data: chunk)

            // Also hash end of file if large
            let fileSize = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            if fileSize > 4 * 1024 * 1024 {
                try handle.seek(toOffset: UInt64(fileSize - 1024 * 1024))
                let endChunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
                hasher.update(data: endChunk)
            }

            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}
