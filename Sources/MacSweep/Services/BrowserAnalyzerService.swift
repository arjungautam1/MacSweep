import Foundation

public final class BrowserAnalyzerService: @unchecked Sendable {
    public static let shared = BrowserAnalyzerService()

    private let fileManager = FileManager.default
    private let scanner = DiskScannerService.shared

    public init() {}

    /// Scans supported browsers and detects profiles and data categories.
    public func scanBrowsers(preservePasswordsAndSignIns: Bool = true) -> [BrowserItem] {
        let home = fileManager.homeDirectoryForCurrentUser
        let appSupport = home.appendingPathComponent("Library/Application Support")
        let caches = home.appendingPathComponent("Library/Caches")

        var items: [BrowserItem] = []

        let browserConfigs: [(BrowserType, URL, URL?)] = [
            (
                .chrome,
                appSupport.appendingPathComponent("Google/Chrome"),
                caches.appendingPathComponent("Google/Chrome")
            ),
            (
                .arc,
                appSupport.appendingPathComponent("Arc/User Data"),
                caches.appendingPathComponent("company.thebrowser.Browser")
            ),
            (
                .brave,
                appSupport.appendingPathComponent("BraveSoftware/Brave-Browser"),
                caches.appendingPathComponent("BraveSoftware/Brave-Browser")
            ),
            (
                .edge,
                appSupport.appendingPathComponent("Microsoft Edge"),
                caches.appendingPathComponent("Microsoft Edge")
            ),
            (
                .vivaldi,
                appSupport.appendingPathComponent("Vivaldi"),
                caches.appendingPathComponent("Vivaldi")
            ),
            (
                .opera,
                appSupport.appendingPathComponent("com.operasoftware.Opera"),
                caches.appendingPathComponent("com.operasoftware.Opera")
            )
        ]

        for (browser, appSupportURL, cacheURL) in browserConfigs {
            guard fileManager.fileExists(atPath: appSupportURL.path) else { continue }

            // 1. Check disk caches in ~/Library/Caches
            if let cacheURL = cacheURL, fileManager.fileExists(atPath: cacheURL.path) {
                let sz = scanner.allocatedSize(of: cacheURL)
                if sz > 5_000_000 {
                    items.append(BrowserItem(
                        browser: browser,
                        profileName: "All Profiles",
                        storageType: .standardCache,
                        siteOrOrigin: nil,
                        path: cacheURL,
                        size: sz,
                        isSelected: true
                    ))
                }
            }

            // 2. Discover Profile directories (Default, Profile 1, Profile 2, etc.)
            let profileDirs = discoverProfileDirectories(at: appSupportURL)
            for profileDir in profileDirs {
                let profileName = profileDir.lastPathComponent

                // Standard Cache inside profile
                let internalCache = profileDir.appendingPathComponent("Cache")
                if fileManager.fileExists(atPath: internalCache.path) {
                    let sz = scanner.allocatedSize(of: internalCache)
                    if sz > 2_000_000 {
                        items.append(BrowserItem(
                            browser: browser,
                            profileName: profileName,
                            storageType: .standardCache,
                            siteOrOrigin: nil,
                            path: internalCache,
                            size: sz,
                            isSelected: true
                        ))
                    }
                }

                // Code Cache (V8 Bytecodes)
                let codeCache = profileDir.appendingPathComponent("Code Cache")
                if fileManager.fileExists(atPath: codeCache.path) {
                    let sz = scanner.allocatedSize(of: codeCache)
                    if sz > 2_000_000 {
                        items.append(BrowserItem(
                            browser: browser,
                            profileName: profileName,
                            storageType: .codeCache,
                            siteOrOrigin: nil,
                            path: codeCache,
                            size: sz,
                            isSelected: true
                        ))
                    }
                }

                // Service Worker Storage
                let swStorage = profileDir.appendingPathComponent("Service Worker")
                if fileManager.fileExists(atPath: swStorage.path) {
                    let sz = scanner.allocatedSize(of: swStorage)
                    if sz > 1_000_000 {
                        items.append(BrowserItem(
                            browser: browser,
                            profileName: profileName,
                            storageType: .serviceWorkerCache,
                            siteOrOrigin: nil,
                            path: swStorage,
                            size: sz,
                            isSelected: true
                        ))
                    }
                }

                // IndexedDB (Offline website data)
                let indexedDB = profileDir.appendingPathComponent("IndexedDB")
                if fileManager.fileExists(atPath: indexedDB.path) {
                    let (dbSize, sites) = analyzeIndexedDBSites(at: indexedDB)
                    if dbSize > 5_000_000 {
                        items.append(BrowserItem(
                            browser: browser,
                            profileName: profileName,
                            storageType: .offlineSiteStorage,
                            siteOrOrigin: sites.joined(separator: ", "),
                            path: indexedDB,
                            size: dbSize,
                            isSelected: false // Safe default: UNCHECKED to preserve drafts
                        ))
                    }
                }

                // History
                let historyFile = profileDir.appendingPathComponent("History")
                if fileManager.fileExists(atPath: historyFile.path) {
                    let sz = scanner.allocatedSize(of: historyFile)
                    if sz > 1_000_000 {
                        items.append(BrowserItem(
                            browser: browser,
                            profileName: profileName,
                            storageType: .history,
                            siteOrOrigin: nil,
                            path: historyFile,
                            size: sz,
                            isSelected: false // Safe default: UNCHECKED
                        ))
                    }
                }

                // Sensitive items: Cookies & Passwords
                // If preservePasswordsAndSignIns is true, do NOT select or include passwords as cleanup candidates!
                let cookiesFile = profileDir.appendingPathComponent("Cookies")
                if fileManager.fileExists(atPath: cookiesFile.path) && !preservePasswordsAndSignIns {
                    let sz = scanner.allocatedSize(of: cookiesFile)
                    items.append(BrowserItem(
                        browser: browser,
                        profileName: profileName,
                        storageType: .cookiesAndAuth,
                        siteOrOrigin: nil,
                        path: cookiesFile,
                        size: sz,
                        isSelected: false
                    ))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    private func discoverProfileDirectories(at url: URL) -> [URL] {
        var profiles: [URL] = []
        let defaultURL = url.appendingPathComponent("Default")
        if fileManager.fileExists(atPath: defaultURL.path) {
            profiles.append(defaultURL)
        }

        if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) {
            for item in contents {
                let name = item.lastPathComponent
                if name.hasPrefix("Profile ") {
                    profiles.append(item)
                }
            }
        }
        return profiles
    }

    private func analyzeIndexedDBSites(at url: URL) -> (Int64, [String]) {
        let size = scanner.allocatedSize(of: url)
        var sites: [String] = []

        if let entries = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            for entry in entries {
                let name = entry.lastPathComponent
                // Format: https_github.com_0.indexeddb.leveldb
                if name.contains(".indexeddb") {
                    let cleaned = name.replacingOccurrences(of: "https_", with: "")
                        .replacingOccurrences(of: "http_", with: "")
                        .components(separatedBy: "_")[0]
                    if !cleaned.isEmpty && !sites.contains(cleaned) {
                        sites.append(cleaned)
                    }
                }
            }
        }
        return (size, Array(sites.prefix(5)))
    }
}
