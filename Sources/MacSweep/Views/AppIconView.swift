import SwiftUI
import AppKit

public struct AppIconView: View {
    public let url: URL?
    public let appName: String?
    public let bundleIdentifier: String?
    public let fallbackSystemName: String
    public let size: CGFloat
    public let badgeSystemName: String?
    public let badgeColor: Color?

    public init(
        url: URL? = nil,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        fallbackSystemName: String = "app.fill",
        size: CGFloat = 36,
        badgeSystemName: String? = nil,
        badgeColor: Color? = nil
    ) {
        self.url = url
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.fallbackSystemName = fallbackSystemName
        self.size = size
        self.badgeSystemName = badgeSystemName
        self.badgeColor = badgeColor
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let nsImage = resolvedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size * 0.65))
                    .foregroundColor(.accentColor)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(Color.gray.opacity(0.12))
                    )
            }

            if let badgeName = badgeSystemName {
                Image(systemName: badgeName)
                    .font(.system(size: max(10, size * 0.35), weight: .bold))
                    .foregroundColor(badgeColor ?? .orange)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: max(12, size * 0.4), height: max(12, size * 0.4))
                    )
                    .offset(x: size * 0.1, y: size * 0.1)
            }
        }
    }

    private var resolvedImage: NSImage? {
        // 1. Direct URL check (e.g. app bundle URL or file path)
        if let url = url, FileManager.default.fileExists(atPath: url.path) {
            return AppIconCache.shared.icon(forURL: url)
        }

        // 2. Try appName or bundleIdentifier lookup
        if let icon = AppIconCache.shared.icon(forAppName: appName, bundleIdentifier: bundleIdentifier) {
            return icon
        }

        // 3. Fallback to icon for path/type if URL is provided
        if let url = url {
            return AppIconCache.shared.icon(forURL: url)
        }

        return nil
    }
}
