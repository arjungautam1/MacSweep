import SwiftUI

public struct SafetyTransparencySheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("What Gets Deleted & Why?")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Complete transparency on how MacSweep identifies files, what is safe to remove, and how to recover.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Golden Rule Banner
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MacSweep's Safety Guarantee")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("MacSweep will **never** touch your Documents, Desktop, Photos library, Keychain passwords, Git repositories, or system operating system files. Only verified disposable caches, build artifacts, and orphaned containers are scanned.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.1))
                    )

                    // Category Breakdown Cards
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Category Breakdown")
                            .font(.title3)
                            .fontWeight(.bold)

                        TransparencyCategoryCard(
                            icon: "cylinder.split.1x2",
                            iconColor: .blue,
                            title: "Application & System Caches",
                            location: "~/Library/Caches",
                            whatItIs: "Temporary cached images, audio buffers, downloaded web assets, and app thumbnails.",
                            whyItExists: "Apps create cache files so they don't have to re-download or re-generate data every time you open them.",
                            whyDelete: "Apps frequently fail to purge old caches. Over months, these accumulate to 15GB–50GB+ of stale files.",
                            consequence: "100% Safe. The next time you launch the app, it simply re-creates a clean, fresh cache.",
                            rebuildTip: "Rebuilds automatically on next app launch."
                        )

                        TransparencyCategoryCard(
                            icon: "hammer",
                            iconColor: .orange,
                            title: "Developer Build Artifacts",
                            location: "Xcode DerivedData, node_modules, SPM & Gradle caches",
                            whatItIs: "Intermediate object files, compiler indices, pre-compiled frameworks, and package dependencies.",
                            whyItExists: "Speeds up daily compilation for projects you actively work on.",
                            whyDelete: "Projects you haven't touched in weeks or months leave behind gigabytes of stale binary build folders.",
                            consequence: "Safe. Source code is never touched. You can re-generate the artifacts whenever needed.",
                            rebuildTip: "Rebuild via 'xcodebuild', 'npm install', or 'cargo build'."
                        )

                        TransparencyCategoryCard(
                            icon: "app.dashed",
                            iconColor: .purple,
                            title: "App Leftovers & Orphaned Containers",
                            location: "~/Library/Containers, ~/Library/Application Support",
                            whatItIs: "Configuration folders, sandbox containers, and log files left behind after dragging an app to the Trash.",
                            whyItExists: "macOS does not automatically erase support folders when you remove an application bundle.",
                            whyDelete: "The parent application is gone, so these orphaned folders take up disk space permanently.",
                            consequence: "Safe to delete. Cleans leftover debris from apps no longer installed on your Mac.",
                            rebuildTip: "If you ever reinstall the app in the future, it creates a fresh default container."
                        )

                        TransparencyCategoryCard(
                            icon: "globe",
                            iconColor: .teal,
                            title: "Browser Cache & Storage",
                            location: "Chrome, Arc, Brave, Edge Profile Caches",
                            whatItIs: "Web page scripts, style sheets, and cached media.",
                            whyItExists: "Loads visited websites faster on subsequent visits.",
                            whyDelete: "Can grow to 5GB–15GB and occasionally causes outdated web pages to render incorrectly.",
                            consequence: "Safe. Website sign-ins, cookies, and saved passwords are strictly preserved by default.",
                            rebuildTip: "Websites reload assets freshly on your next visit."
                        )

                        TransparencyCategoryCard(
                            icon: "doc.text.magnifyingglass",
                            iconColor: .gray,
                            title: "Diagnostic Logs & Crash Reports",
                            location: "~/Library/Logs, /Library/Logs/DiagnosticReports",
                            whatItIs: "Historical crash traces, diagnostic messages, and old application debug transcripts.",
                            whyItExists: "Created by developers to diagnose application crashes.",
                            whyDelete: "Old crash reports from months ago are obsolete and waste storage.",
                            consequence: "100% Safe. Does not affect application function.",
                            rebuildTip: "New logs are generated dynamically if future crashes occur."
                        )
                    }

                    // How Deletion & Recovery Works
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Deletion & Recovery Works")
                            .font(.title3)
                            .fontWeight(.bold)

                        VStack(spacing: 12) {
                            RecoveryStepRow(
                                number: "1",
                                title: "Recoverable by Default (macOS Trash)",
                                description: "MacSweep moves files to your macOS Trash. If you ever change your mind, open macOS Trash, right-click the item, and select 'Put Back' to restore it immediately."
                            )

                            RecoveryStepRow(
                                number: "2",
                                title: "Dry Run Simulation Mode",
                                description: "Toggle 'Dry Run' in the toolbar to simulate the complete cleanup without touching a single file on disk. You get an exact itemized report of what would happen."
                            )

                            RecoveryStepRow(
                                number: "3",
                                title: "Granular Item Selection",
                                description: "You have complete control in the Review Plan sheet. Select or deselect individual items, reveal files in Finder, and only proceed when you are satisfied."
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 620, minHeight: 640)
    }
}

public struct TransparencyCategoryCard: View {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let location: String
    public let whatItIs: String
    public let whyItExists: String
    public let whyDelete: String
    public let consequence: String
    public let rebuildTip: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("What it is:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 85, alignment: .leading)
                    Text(whatItIs)
                        .font(.caption)
                }

                HStack(alignment: .top) {
                    Text("Why it exists:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 85, alignment: .leading)
                    Text(whyItExists)
                        .font(.caption)
                }

                HStack(alignment: .top) {
                    Text("Why delete:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 85, alignment: .leading)
                    Text(whyDelete)
                        .font(.caption)
                }

                HStack(alignment: .top) {
                    Text("Result:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .frame(width: 85, alignment: .leading)
                    Text(consequence)
                        .font(.caption)
                }

                HStack(alignment: .top) {
                    Text("Rebuilding:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(width: 85, alignment: .leading)
                    Text(rebuildTip)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

public struct RecoveryStepRow: View {
    public let number: String
    public let title: String
    public let description: String

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
