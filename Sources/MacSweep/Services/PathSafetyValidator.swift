import Foundation

/// Critical safety validator to ensure no system-critical, SIP, or root user directories are ever destroyed.
public struct PathSafetyValidator: Sendable {
    /// Critical system paths that must NEVER be deleted or modified by MacSweep.
    public static let blockedSystemPrefixes: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/private/etc",
        "/private/var/db",
        "/Library/Apple",
        "/Library/SystemExtensions",
        "/Library/Preferences/SystemConfiguration"
    ]

    /// Critical user paths that cannot be deleted as a whole.
    public static func isProtectedUserPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path

        // Check if path is home directory itself or top-level user folders
        if path == home || path == "/" { return true }

        let forbiddenExact = [
            home,
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Library",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.zshrc",
            "\(home)/.bash_profile",
            "\(home)/.bashrc"
        ]

        if forbiddenExact.contains(path) {
            return true
        }

        // Check system prefixes
        for prefix in blockedSystemPrefixes {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }

        // Protect root .git folders directly from batch delete
        if path.hasSuffix("/.git") {
            return true
        }

        return false
    }

    /// Deduplicates nested targets so that if `/A` and `/A/B` are both selected,
    /// only `/A` is kept in the plan. This prevents double-counting and deletion errors.
    public static func deduplicateNestedPaths(_ urls: [URL]) -> [URL] {
        let sorted = urls.map { $0.standardizedFileURL }.sorted {
            $0.path.count < $1.path.count
        }

        var unique: [URL] = []
        for url in sorted {
            let path = url.path
            let isSubpathOfExisting = unique.contains { existing in
                path.hasPrefix(existing.path + "/")
            }
            if !isSubpathOfExisting {
                unique.append(url)
            }
        }
        return unique
    }
}
