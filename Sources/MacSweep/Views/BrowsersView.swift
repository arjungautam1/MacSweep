import SwiftUI
import AppKit

public struct BrowsersView: View {
    @ObservedObject var appState: AppState
    @State private var selectedBrowser: BrowserType? = nil

    public var filteredBrowserItems: [BrowserItem] {
        if let sel = selectedBrowser {
            return appState.browserItems.filter { $0.browser == sel }
        }
        return appState.browserItems
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Master Security Option Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Keep my passwords and existing website sign-ins")
                                .font(.headline)
                        }
                        Text("When enabled (recommended), cookies, saved passwords, authentication tokens, and autofill vaults are strictly preserved. You will remain logged into all websites.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $appState.preservePasswordsAndSignIns)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.12))
                )

                // Browser Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All Browsers (\(appState.browserItems.count))",
                            isSelected: selectedBrowser == nil,
                            action: { selectedBrowser = nil }
                        )

                        ForEach(BrowserType.allCases) { bType in
                            let count = appState.browserItems.filter { $0.browser == bType }.count
                            if count > 0 {
                                FilterPill(
                                    title: "\(bType.rawValue) (\(count))",
                                    isSelected: selectedBrowser == bType,
                                    action: { selectedBrowser = bType }
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Items List
            if filteredBrowserItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No browser caches or site storage found.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Run a scan from the Overview tab to detect Chrome, Arc, Brave, and Edge profiles.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredBrowserItems) { item in
                    BrowserItemRowView(item: item)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

public struct BrowserItemRowView: View {
    public let item: BrowserItem

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AppIconView(
                appName: item.browser.rawValue,
                fallbackSystemName: "globe",
                size: 28
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(item.browser.rawValue) • \(item.profileName)")
                        .font(.headline)
                    Text(item.storageType.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray.opacity(0.2)))
                    Spacer()
                    Text(item.size.formattedBytes)
                        .font(.headline)
                }

                if let sites = item.siteOrOrigin, !sites.isEmpty {
                    Text("Identified Websites: \(sites)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(item.storageType.riskDescription)
                    .font(.caption)
                    .foregroundColor(item.storageType.isSafeByDefault ? .secondary : .orange)

                Text(item.path.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}
