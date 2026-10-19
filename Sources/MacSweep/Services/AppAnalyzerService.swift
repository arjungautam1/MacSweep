import Foundation

public final class AppAnalyzerService: @unchecked Sendable {
    public static let shared = AppAnalyzerService()

    private let fileManager = FileManager.default
    private let scanner = DiskScannerService.shared

    public init() {}

    /// Scans installed applications in /Applications, /System/Applications, and ~/Applications.
    public func scanInstalledApplications() -> [AppItem] {
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var apps: [AppItem] = []
        var seenBundleIds = Set<String>()

        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey]) else {
                continue
            }

            for item in contents where item.pathExtension == "app" {
                let bundle = Bundle(url: item)
                let bundleId = bundle?.bundleIdentifier ?? "unknown.\(item.deletingPathExtension().lastPathComponent)"
                let appName = (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
                    ?? item.deletingPathExtension().lastPathComponent
                let version = (bundle?.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"

                let binarySize = scanner.allocatedSize(of: item)
                let related = findRelatedFiles(forBundleId: bundleId, appName: appName)

                let appItem = AppItem(
                    bundleURL: item,
                    bundleIdentifier: bundleId,
                    appName: appName,
                    version: version,
                    isSystemApp: item.path.hasPrefix("/System"),
                    appBinarySize: binarySize,
                    relatedFiles: related,
                    isLeftover: false
                )

                apps.append(appItem)
                seenBundleIds.insert(bundleId)
            }
        }

        // Detect Leftovers from uninstalled applications
        let leftovers = detectAppLeftovers(installedBundleIds: seenBundleIds)
        apps.append(contentsOf: leftovers)

        // Sort descending by total size
        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    /// Finds all related files for an app bundle ID and app name across user Library locations.
    public func findRelatedFiles(forBundleId bundleId: String, appName: String) -> [AppRelatedFile] {
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")

        var related: [AppRelatedFile] = []

        // 1. Caches
        let cacheLocations = [
            library.appendingPathComponent("Caches/\(bundleId)"),
            library.appendingPathComponent("Caches/\(appName)")
        ]
        for loc in cacheLocations where fileManager.fileExists(atPath: loc.path) {
            let sz = scanner.allocatedSize(of: loc)
            if sz > 0 {
                related.append(AppRelatedFile(
                    path: loc,
                    type: .cache,
                    size: sz,
                    isSelected: true,
                    explanation: "Application cache data. Safe to clear; rebuilt when the app runs.",
                    isRebuildable: true
                ))
            }
        }

        // 2. Preferences (.plist)
        let prefURL = library.appendingPathComponent("Preferences/\(bundleId).plist")
        if fileManager.fileExists(atPath: prefURL.path) {
            let sz = scanner.allocatedSize(of: prefURL)
            related.append(AppRelatedFile(
                path: prefURL,
                type: .preference,
                size: sz,
                isSelected: false,
                explanation: "User settings, window positions, and preference flags.",
                isRebuildable: true,
                affectsSettings: true
            ))
        }

        // 3. Application Support
        let appSupportLocs = [
            library.appendingPathComponent("Application Support/\(appName)"),
            library.appendingPathComponent("Application Support/\(bundleId)")
        ]
        for loc in appSupportLocs where fileManager.fileExists(atPath: loc.path) {
            let sz = scanner.allocatedSize(of: loc)
            if sz > 0 {
                related.append(AppRelatedFile(
                    path: loc,
                    type: .applicationSupport,
                    size: sz,
                    isSelected: false,
                    explanation: "Application runtime databases, templates, and support assets.",
                    isRebuildable: false,
                    affectsSettings: true
                ))
            }
        }

        // 4. Containers
        let containerURL = library.appendingPathComponent("Containers/\(bundleId)")
        if fileManager.fileExists(atPath: containerURL.path) {
            let sz = scanner.allocatedSize(of: containerURL)
            if sz > 0 {
                related.append(AppRelatedFile(
                    path: containerURL,
                    type: .container,
                    size: sz,
                    isSelected: false,
                    explanation: "macOS App Sandbox container containing app-specific documents and isolated caches.",
                    isRebuildable: false,
                    affectsSettings: true
                ))
            }
        }

        // 5. Saved Application State
        let stateURL = library.appendingPathComponent("Saved Application State/\(bundleId).savedState")
        if fileManager.fileExists(atPath: stateURL.path) {
            let sz = scanner.allocatedSize(of: stateURL)
            related.append(AppRelatedFile(
                path: stateURL,
                type: .savedState,
                size: sz,
                isSelected: true,
                explanation: "Saved UI window state from previous session. Safe to remove.",
                isRebuildable: true
            ))
        }

        // 6. WebKit & HTTPStorages
        let webKitURL = library.appendingPathComponent("WebKit/\(bundleId)")
        if fileManager.fileExists(atPath: webKitURL.path) {
            let sz = scanner.allocatedSize(of: webKitURL)
            related.append(AppRelatedFile(
                path: webKitURL,
                type: .webKitData,
                size: sz,
                isSelected: true,
                explanation: "Embedded WebKit web view caches and storages.",
                isRebuildable: true
            ))
        }

        // 7. Logs
        let logsURL = library.appendingPathComponent("Logs/\(appName)")
        if fileManager.fileExists(atPath: logsURL.path) {
            let sz = scanner.allocatedSize(of: logsURL)
            related.append(AppRelatedFile(
                path: logsURL,
                type: .log,
                size: sz,
                isSelected: true,
                explanation: "Application diagnostic and activity logs.",
                isRebuildable: true
            ))
        }

        return related
    }

    /// Detects orphaned data left behind by uninstalled applications.
    public func detectAppLeftovers(installedBundleIds: Set<String>) -> [AppItem] {
        let home = fileManager.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        let containers = home.appendingPathComponent("Library/Containers")

        var leftovers: [AppItem] = []

        // Scan Containers for bundle IDs no longer installed
        if let containerItems = try? fileManager.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil) {
            for item in containerItems {
                let id = item.lastPathComponent
                if id.contains(".") && !id.hasPrefix("com.apple.") && !installedBundleIds.contains(id) {
                    let sz = scanner.allocatedSize(of: item)
                    if sz > 2_000_000 { // 2MB+
                        let name = id.components(separatedBy: ".").last?.capitalized ?? id
                        let relatedFile = AppRelatedFile(
                            path: item,
                            type: .leftover,
                            size: sz,
                            isSelected: false,
                            explanation: "Orphaned container left behind after removing \(name).",
                            isRebuildable: false
                        )

                        let leftoverApp = AppItem(
                            bundleURL: item,
                            bundleIdentifier: id,
                            appName: name,
                            version: "Uninstalled",
                            isSystemApp: false,
                            appBinarySize: 0,
                            relatedFiles: [relatedFile],
                            isLeftover: true,
                            leftoverEvidence: "Container found in ~/Library/Containers/\(id) with no corresponding app in /Applications."
                        )
                        leftovers.append(leftoverApp)
                    }
                }
            }
        }

        // Scan Application Support for reverse-DNS app folders no longer installed
        if let appSupportItems = try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            for item in appSupportItems {
                let id = item.lastPathComponent
                if id.contains(".") && !id.hasPrefix("com.apple.") && !installedBundleIds.contains(id) {
                    let sz = scanner.allocatedSize(of: item)
                    if sz > 5_000_000 {
                        let name = id.components(separatedBy: ".").last?.capitalized ?? id
                        let relatedFile = AppRelatedFile(
                            path: item,
                            type: .leftover,
                            size: sz,
                            isSelected: false,
                            explanation: "Orphaned Application Support data for \(name).",
                            isRebuildable: false
                        )

                        let leftoverApp = AppItem(
                            bundleURL: item,
                            bundleIdentifier: id,
                            appName: name,
                            version: "Uninstalled",
                            isSystemApp: false,
                            appBinarySize: 0,
                            relatedFiles: [relatedFile],
                            isLeftover: true,
                            leftoverEvidence: "Application Support directory found in ~/Library/Application Support/\(id) with no installed app."
                        )
                        leftovers.append(leftoverApp)
                    }
                }
            }
        }

        return leftovers
    }
}
