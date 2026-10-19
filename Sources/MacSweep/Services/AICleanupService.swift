import Foundation
import SwiftUI
import Combine

public enum AIToolCategory: String, CaseIterable, Identifiable, Sendable {
    case safeCaches = "Caches & Old Versions"
    case chatsAndWorktrees = "Chats & Worktrees"
    case unusedModelsAndTools = "Models & Tool Leftovers"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .safeCaches:
            return "Caches can be rebuilt and old builds are no longer needed."
        case .chatsAndWorktrees:
            return "Review chat sessions, transcripts and worktrees one by one."
        case .unusedModelsAndTools:
            return "Uninstall unused tools, compact databases or remove unused models."
        }
    }
}

public struct AIItem: Identifiable, Sendable {
    public let id: String
    public let toolName: String
    public let title: String
    public let detail: String
    public let category: AIToolCategory
    public let path: URL
    public let size: Int64
    public let modifiedDate: Date
    public var isSelected: Bool
    public let isSafeByDefault: Bool

    public var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: modifiedDate, to: Date()).day ?? 0
    }
}

@MainActor
public final class AICleanupService: ObservableObject {
    public static let shared = AICleanupService()

    @Published public var items: [AIItem] = []
    @Published public var isScanning: Bool = false
    @Published public var lastScanDate: Date?
    @Published public var selectedRetentionDays: Int = 14 // older than 14 days by default

    private let fileManager = FileManager.default

    public init() {}

    public var totalReclaimableBytes: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    public var selectedBytes: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public func scanAIData() async {
        isScanning = true
        var discovered: [AIItem] = []
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Claude Code (~/.claude)
        let claudeDir = home.appendingPathComponent(".claude")
        if fileManager.fileExists(atPath: claudeDir.path) {
            // Caches
            let cacheDir = claudeDir.appendingPathComponent("cache")
            if let size = folderSize(at: cacheDir), size > 0 {
                discovered.append(AIItem(
                    id: "claude-cache",
                    toolName: "Claude Code",
                    title: "Claude Code Caches & Telemetry",
                    detail: "Cached API responses and telemetry files",
                    category: .safeCaches,
                    path: cacheDir,
                    size: size,
                    modifiedDate: modificationDate(at: cacheDir),
                    isSelected: true,
                    isSafeByDefault: true
                ))
            }

            // Sessions
            let sessionsDir = claudeDir.appendingPathComponent("sessions")
            if let size = folderSize(at: sessionsDir), size > 0 {
                discovered.append(AIItem(
                    id: "claude-sessions",
                    toolName: "Claude Code",
                    title: "Claude Code Chat Transcripts",
                    detail: "Archived prompt sessions and CLI interaction logs",
                    category: .chatsAndWorktrees,
                    path: sessionsDir,
                    size: size,
                    modifiedDate: modificationDate(at: sessionsDir),
                    isSelected: false,
                    isSafeByDefault: false
                ))
            }
        }

        // 2. OpenAI / Codex CLI (~/.codex)
        let codexDir = home.appendingPathComponent(".codex")
        if fileManager.fileExists(atPath: codexDir.path) {
            let cacheDir = codexDir.appendingPathComponent("cache")
            if let size = folderSize(at: cacheDir), size > 0 {
                discovered.append(AIItem(
                    id: "codex-cache",
                    toolName: "Codex",
                    title: "Codex Tool Caches",
                    detail: "Temporary build outputs and tool runs",
                    category: .safeCaches,
                    path: cacheDir,
                    size: size,
                    modifiedDate: modificationDate(at: cacheDir),
                    isSelected: true,
                    isSafeByDefault: true
                ))
            }

            let sessionsDir = codexDir.appendingPathComponent("sessions")
            if let size = folderSize(at: sessionsDir), size > 0 {
                discovered.append(AIItem(
                    id: "codex-sessions",
                    toolName: "Codex",
                    title: "Codex Agent Sessions",
                    detail: "Historical code agent sessions and execution records",
                    category: .chatsAndWorktrees,
                    path: sessionsDir,
                    size: size,
                    modifiedDate: modificationDate(at: sessionsDir),
                    isSelected: false,
                    isSafeByDefault: false
                ))
            }

            let worktreesDir = codexDir.appendingPathComponent("worktrees")
            if let size = folderSize(at: worktreesDir), size > 0 {
                discovered.append(AIItem(
                    id: "codex-worktrees",
                    toolName: "Codex",
                    title: "Codex Git Worktrees",
                    detail: "Merged git worktrees left behind by automated runs",
                    category: .chatsAndWorktrees,
                    path: worktreesDir,
                    size: size,
                    modifiedDate: modificationDate(at: worktreesDir),
                    isSelected: true,
                    isSafeByDefault: true
                ))
            }
        }

        // 3. Cursor (~/Library/Application Support/Cursor)
        let cursorDir = home.appendingPathComponent("Library/Application Support/Cursor")
        if fileManager.fileExists(atPath: cursorDir.path) {
            let workspaceStorage = cursorDir.appendingPathComponent("User/workspaceStorage")
            if let size = folderSize(at: workspaceStorage), size > 0 {
                discovered.append(AIItem(
                    id: "cursor-workspace-storage",
                    toolName: "Cursor",
                    title: "Cursor Workspace State & AI Index",
                    detail: "Project indexing cache, state trees and AI chat history",
                    category: .safeCaches,
                    path: workspaceStorage,
                    size: size,
                    modifiedDate: modificationDate(at: workspaceStorage),
                    isSelected: false,
                    isSafeByDefault: true
                ))
            }

            let cursorCaches = home.appendingPathComponent("Library/Caches/com.todesktop.230313mzl4w4u92")
            if let size = folderSize(at: cursorCaches), size > 0 {
                discovered.append(AIItem(
                    id: "cursor-cache",
                    toolName: "Cursor",
                    title: "Cursor App Caches",
                    detail: "Rebuildable webview and network caches",
                    category: .safeCaches,
                    path: cursorCaches,
                    size: size,
                    modifiedDate: modificationDate(at: cursorCaches),
                    isSelected: true,
                    isSafeByDefault: true
                ))
            }
        }

        // 4. HuggingFace Hub Cache (~/.cache/huggingface)
        let hfDir = home.appendingPathComponent(".cache/huggingface/hub")
        if fileManager.fileExists(atPath: hfDir.path), let size = folderSize(at: hfDir), size > 0 {
            discovered.append(AIItem(
                id: "hf-models",
                toolName: "Hugging Face",
                title: "Hugging Face Model Cache",
                detail: "Downloaded transformers weights, snapshots and tokenizers",
                category: .unusedModelsAndTools,
                path: hfDir,
                size: size,
                modifiedDate: modificationDate(at: hfDir),
                isSelected: false,
                isSafeByDefault: false
            ))
        }

        // 5. Ollama Models (~/.ollama/models)
        let ollamaDir = home.appendingPathComponent(".ollama/models")
        if fileManager.fileExists(atPath: ollamaDir.path), let size = folderSize(at: ollamaDir), size > 0 {
            discovered.append(AIItem(
                id: "ollama-models",
                toolName: "Ollama",
                title: "Local Ollama LLM Models",
                detail: "Downloaded GGUF models and parameter weights",
                category: .unusedModelsAndTools,
                path: ollamaDir,
                size: size,
                modifiedDate: modificationDate(at: ollamaDir),
                isSelected: false,
                isSafeByDefault: false
            ))
        }

        // 6. LM Studio (~/.cache/lm-studio)
        let lmStudioDir = home.appendingPathComponent(".cache/lm-studio")
        if fileManager.fileExists(atPath: lmStudioDir.path), let size = folderSize(at: lmStudioDir), size > 0 {
            discovered.append(AIItem(
                id: "lm-studio-cache",
                toolName: "LM Studio",
                title: "LM Studio Cache & Downloads",
                detail: "Downloaded model shards and runtime temporary files",
                category: .unusedModelsAndTools,
                path: lmStudioDir,
                size: size,
                modifiedDate: modificationDate(at: lmStudioDir),
                isSelected: false,
                isSafeByDefault: false
            ))
        }

        // 7. Python AI / PyTorch Cache (~/.cache/torch)
        let torchCache = home.appendingPathComponent(".cache/torch")
        if fileManager.fileExists(atPath: torchCache.path), let size = folderSize(at: torchCache), size > 0 {
            discovered.append(AIItem(
                id: "torch-cache",
                toolName: "PyTorch",
                title: "PyTorch Hub & Kernel Cache",
                detail: "Compiled Metal/MPS kernels and pre-trained weights",
                category: .safeCaches,
                path: torchCache,
                size: size,
                modifiedDate: modificationDate(at: torchCache),
                isSelected: true,
                isSafeByDefault: true
            ))
        }

        self.items = discovered
        self.lastScanDate = Date()
        self.isScanning = false
    }

    public func cleanSelectedItems(useTrash: Bool = true) async -> (cleanedCount: Int, cleanedBytes: Int64) {
        var count = 0
        var bytes: Int64 = 0

        for item in items where item.isSelected {
            do {
                if useTrash {
                    try fileManager.trashItem(at: item.path, resultingItemURL: nil)
                } else {
                    try fileManager.removeItem(at: item.path)
                }
                count += 1
                bytes += item.size
            } catch {
                print("Failed to remove AI item at \(item.path): \(error)")
            }
        }

        await scanAIData()
        return (count, bytes)
    }

    public func toggleItemSelection(_ id: String) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isSelected.toggle()
        }
    }

    public func selectAll(in category: AIToolCategory, select: Bool) {
        for idx in items.indices where items[idx].category == category {
            items[idx].isSelected = select
        }
    }

    // Helper functions
    private func folderSize(at url: URL) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]) else { continue }
            let size = resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? resourceValues.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    private func modificationDate(at url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? Date()
    }
}
