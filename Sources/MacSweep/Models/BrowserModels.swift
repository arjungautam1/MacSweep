import Foundation

public enum BrowserType: String, CaseIterable, Identifiable, Sendable {
    case chrome = "Google Chrome"
    case arc = "Arc"
    case brave = "Brave"
    case edge = "Microsoft Edge"
    case vivaldi = "Vivaldi"
    case opera = "Opera"
    case safari = "Safari"

    public var id: String { rawValue }

    public var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .arc: return "company.thebrowser.Browser"
        case .brave: return "com.brave.Browser"
        case .edge: return "com.microsoft.edgemac"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .opera: return "com.operasoftware.Opera"
        case .safari: return "com.apple.Safari"
        }
    }
}

public enum BrowserStorageType: String, CaseIterable, Sendable {
    case standardCache = "Network & Media Cache"
    case codeCache = "V8 JavaScript & WASM Code Cache"
    case serviceWorkerCache = "Service Worker Cache"
    case offlineSiteStorage = "Offline Website Data (IndexedDB)"
    case history = "Browsing & Download History"
    case cookiesAndAuth = "Cookies & Active Sessions"
    case passwords = "Saved Passwords & Vaults"
    case extensions = "Installed Browser Extensions"

    public var isSafeByDefault: Bool {
        switch self {
        case .standardCache, .codeCache, .serviceWorkerCache:
            return true
        case .offlineSiteStorage, .history, .cookiesAndAuth, .passwords, .extensions:
            return false
        }
    }

    public var riskDescription: String {
        switch self {
        case .standardCache:
            return "Disposable network files and images. Safe to remove; reloaded when visiting pages."
        case .codeCache:
            return "Compiled JavaScript bytecodes for speed. Safe to remove; rebuilt on demand."
        case .serviceWorkerCache:
            return "Offline service worker responses. Safe to clear; refreshes automatically online."
        case .offlineSiteStorage:
            return "⚠️ May contain offline drafts, cached webapp documents, or unsynced media."
        case .history:
            return "⚠️ List of visited pages. If browser sync is active, deleting may sync deletion across devices."
        case .cookiesAndAuth:
            return "🚨 Contains login tokens and sessions. Removing will log you out of all websites."
        case .passwords:
            return "🚨 Stored passwords and autofill credentials. DO NOT remove unless resetting completely."
        case .extensions:
            return "⚠️ Installed add-ons and browser plugins."
        }
    }
}

public struct BrowserItem: Identifiable, Sendable {
    public let id: UUID
    public let browser: BrowserType
    public let profileName: String
    public let storageType: BrowserStorageType
    public let siteOrOrigin: String?
    public let path: URL
    public let size: Int64
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        browser: BrowserType,
        profileName: String,
        storageType: BrowserStorageType,
        siteOrOrigin: String? = nil,
        path: URL,
        size: Int64,
        isSelected: Bool = false
    ) {
        self.id = id
        self.browser = browser
        self.profileName = profileName
        self.storageType = storageType
        self.siteOrOrigin = siteOrOrigin
        self.path = path
        self.size = size
        self.isSelected = isSelected
    }
}
