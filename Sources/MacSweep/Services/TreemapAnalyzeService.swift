import Foundation
import SwiftUI
import Combine

public struct TreemapItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let size: Int64
    public let isDirectory: Bool
    public let kind: FileKind
    public var children: [TreemapItem]?

    public var formattedSize: String {
        size.formattedBytes
    }

    public var color: Color {
        switch kind {
        case .application: return Color.blue
        case .video: return Color.purple
        case .developer: return Color.orange
        case .archive: return Color.yellow
        case .image: return Color.green
        case .audio: return Color.pink
        case .document: return Color.teal
        case .other: return Color.gray
        }
    }
}

public enum FileKind: String, Sendable {
    case application = "Application"
    case video = "Video"
    case developer = "Developer"
    case archive = "Archive"
    case image = "Image"
    case audio = "Audio"
    case document = "Document"
    case other = "Other"

    public static func from(url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "app": return .application
        case "mp4", "mov", "mkv", "avi", "webm", "m4v": return .video
        case "swift", "js", "ts", "py", "rs", "go", "cpp", "c", "h", "java", "json", "yml", "yaml": return .developer
        case "dmg", "pkg", "zip", "tar", "gz", "7z", "rar", "iso": return .archive
        case "jpg", "jpeg", "png", "heic", "webp", "gif", "svg", "raw", "tiff": return .image
        case "mp3", "wav", "m4a", "flac", "aac", "ogg": return .audio
        case "pdf", "docx", "doc", "xlsx", "pptx", "txt", "md": return .document
        default:
            let name = url.lastPathComponent.lowercased()
            if name == "node_modules" || name == ".git" || name == "deriveddata" {
                return .developer
            }
            return .other
        }
    }
}

@MainActor
public final class TreemapAnalyzeService: ObservableObject {
    public static let shared = TreemapAnalyzeService()

    @Published public var currentFolderURL: URL
    @Published public var pathBreadcrumbs: [URL] = []
    @Published public var currentItems: [TreemapItem] = []
    @Published public var isAnalyzing: Bool = false
    @Published public var selectedItem: TreemapItem?
    @Published public var currentFolderTotalBytes: Int64 = 0

    private let fileManager = FileManager.default

    public init() {
        let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        self.currentFolderURL = defaultURL
        self.pathBreadcrumbs = [defaultURL]
    }

    public func analyzeFolder(at targetURL: URL) async {
        isAnalyzing = true
        currentFolderURL = targetURL
        updateBreadcrumbs(to: targetURL)

        var items: [TreemapItem] = []
        var totalBytes: Int64 = 0

        guard let contents = try? fileManager.contentsOfDirectory(
            at: targetURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            isAnalyzing = false
            return
        }

        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let size = isDir ? folderSize(at: url) : (fileSize(at: url) ?? 0)
            guard size > 0 else { continue }
            totalBytes += size

            let kind = isDir ? (url.pathExtension == "app" ? .application : FileKind.from(url: url)) : FileKind.from(url: url)

            items.append(TreemapItem(
                id: url.path,
                name: url.lastPathComponent,
                url: url,
                size: size,
                isDirectory: isDir && url.pathExtension != "app",
                kind: kind,
                children: nil
            ))
        }

        self.currentItems = items.sorted { $0.size > $1.size }
        self.currentFolderTotalBytes = totalBytes
        self.isAnalyzing = false
    }

    public func navigateTo(url: URL) {
        Task {
            await analyzeFolder(at: url)
        }
    }

    public func navigateUp() {
        guard pathBreadcrumbs.count > 1 else { return }
        let parent = pathBreadcrumbs[pathBreadcrumbs.count - 2]
        navigateTo(url: parent)
    }

    private func updateBreadcrumbs(to url: URL) {
        var crumbs: [URL] = []
        var cur: URL? = url
        while let c = cur, c.path != "/" {
            crumbs.insert(c, at: 0)
            cur = c.deletingLastPathComponent()
        }
        crumbs.insert(URL(fileURLWithPath: "/"), at: 0)
        self.pathBreadcrumbs = crumbs
    }

    public func deleteItem(item: TreemapItem, useTrash: Bool = true) {
        do {
            if useTrash {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
            } else {
                try fileManager.removeItem(at: item.url)
            }
            navigateTo(url: currentFolderURL)
        } catch {
            print("Failed to delete \(item.url): \(error)")
        }
    }

    private func folderSize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        var itemsExamined = 0
        for case let fileURL as URL in enumerator {
            itemsExamined += 1
            if itemsExamined > 5000 { break } // avoid deep locks on massive system dirs
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }
        return total
    }

    private func fileSize(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map { Int64($0) }
    }
}
