import Foundation

public final class DeveloperAnalyzerService: @unchecked Sendable {
    public static let shared = DeveloperAnalyzerService()

    private let fileManager = FileManager.default
    private let scanner = DiskScannerService.shared

    public init() {}

    /// Scans developer directories for rebuildable artifacts and build caches.
    public func scanDeveloperArtifacts() -> [DeveloperCandidateItem] {
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates: [DeveloperCandidateItem] = []

        // 1. Xcode DerivedData
        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if fileManager.fileExists(atPath: derivedData.path) {
            if let projects = try? fileManager.contentsOfDirectory(at: derivedData, includingPropertiesForKeys: [.isDirectoryKey]) {
                for proj in projects where proj.lastPathComponent != "ModuleCache.noindex" {
                    let sz = scanner.allocatedSize(of: proj)
                    if sz > 10_000_000 { // 10MB+
                        let name = proj.lastPathComponent.components(separatedBy: "-").first ?? proj.lastPathComponent
                        candidates.append(DeveloperCandidateItem(
                            type: .xcodeDerivedData,
                            projectName: name,
                            projectRoot: nil,
                            path: proj,
                            size: sz,
                            rebuildCommand: "Product > Build in Xcode (Cmd+B)",
                            explanation: "Intermediate build objects, symbol indexes, and module caches. Rebuilt when you build the project in Xcode.",
                            isSelected: true
                        ))
                    }
                }
            }
        }

        // 2. Xcode Archives (older than 30 days)
        let archives = home.appendingPathComponent("Library/Developer/Xcode/Archives")
        if fileManager.fileExists(atPath: archives.path) {
            let sz = scanner.allocatedSize(of: archives)
            if sz > 50_000_000 {
                candidates.append(DeveloperCandidateItem(
                    type: .xcodeArchives,
                    projectName: "All Xcode Archives",
                    projectRoot: nil,
                    path: archives,
                    size: sz,
                    rebuildCommand: "Product > Archive in Xcode",
                    explanation: "Exported application release archives and dSYMs.",
                    isSelected: false // Safe default: unchecked
                ))
            }
        }

        // 3. Package Manager Global Caches
        let pmCaches: [(String, URL, String)] = [
            ("npm Cache", home.appendingPathComponent(".npm"), "npm cache clean --force"),
            ("pnpm Store", home.appendingPathComponent("Library/pnpm/store"), "pnpm store prune"),
            ("Bun Install Cache", home.appendingPathComponent(".bun/install/cache"), "bun pm cache rm"),
            ("Yarn Cache", home.appendingPathComponent("Library/Caches/Yarn"), "yarn cache clean"),
            ("Homebrew Cache", home.appendingPathComponent("Library/Caches/Homebrew"), "brew cleanup"),
            ("Cargo Registry Cache", home.appendingPathComponent(".cargo/registry/cache"), "cargo cache --autoclean")
        ]

        for (pmName, url, pruneCmd) in pmCaches where fileManager.fileExists(atPath: url.path) {
            let sz = scanner.allocatedSize(of: url)
            if sz > 15_000_000 {
                candidates.append(DeveloperCandidateItem(
                    type: .packageManagerCache,
                    projectName: pmName,
                    projectRoot: nil,
                    path: url,
                    size: sz,
                    rebuildCommand: pruneCmd,
                    explanation: "Cached downloaded packages and tarballs. Re-downloaded when installing packages.",
                    isSelected: true
                ))
            }
        }

        // 4. Common Developer Project Roots (Desktop, Documents, Projects folders)
        let projectSearchDirs = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer")
        ]

        for baseDir in projectSearchDirs where fileManager.fileExists(atPath: baseDir.path) {
            scanDirectoryForProjects(baseDir, depth: 0, maxDepth: 3, candidates: &candidates)
        }

        return candidates.sorted { $0.size > $1.size }
    }

    private func scanDirectoryForProjects(
        _ directory: URL,
        depth: Int,
        maxDepth: Int,
        candidates: inout [DeveloperCandidateItem]
    ) {
        guard depth < maxDepth else { return }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let name = item.lastPathComponent

            // Check if this directory is node_modules
            if name == "node_modules" {
                let sz = scanner.allocatedSize(of: item)
                if sz > 20_000_000 {
                    let parentProject = directory.lastPathComponent
                    candidates.append(DeveloperCandidateItem(
                        type: .nodeModules,
                        projectName: parentProject,
                        projectRoot: directory,
                        path: item,
                        size: sz,
                        rebuildCommand: "npm install (or pnpm / bun / yarn install)",
                        explanation: "JavaScript third-party dependencies. Source code and package.json are completely safe.",
                        isSelected: false // Safe default: unchecked, user chooses
                    ))
                }
                continue // don't traverse into node_modules
            }

            // Check if this directory is a build output (.next, dist, build, .turbo)
            if [".next", "dist", "build", ".turbo", "out"].contains(name) {
                let sz = scanner.allocatedSize(of: item)
                if sz > 5_000_000 {
                    let parentProject = directory.lastPathComponent
                    candidates.append(DeveloperCandidateItem(
                        type: .webBuildOutput,
                        projectName: parentProject,
                        projectRoot: directory,
                        path: item,
                        size: sz,
                        rebuildCommand: "npm run build (or npx next build)",
                        explanation: "Generated production web bundle. Easily rebuilt from source code.",
                        isSelected: false
                    ))
                }
                continue
            }

            // Check if Rust target folder
            if name == "target" && fileManager.fileExists(atPath: directory.appendingPathComponent("Cargo.toml").path) {
                let sz = scanner.allocatedSize(of: item)
                if sz > 20_000_000 {
                    candidates.append(DeveloperCandidateItem(
                        type: .webBuildOutput,
                        projectName: directory.lastPathComponent,
                        projectRoot: directory,
                        path: item,
                        size: sz,
                        rebuildCommand: "cargo build",
                        explanation: "Rust build artifacts. Rebuilt by cargo.",
                        isSelected: false
                    ))
                }
                continue
            }

            // Recurse into subdirectories
            if !["Library", "Applications", ".git"].contains(name) {
                scanDirectoryForProjects(item, depth: depth + 1, maxDepth: maxDepth, candidates: &candidates)
            }
        }
    }
}
