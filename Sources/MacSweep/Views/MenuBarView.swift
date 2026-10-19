import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var topLargeFiles: [LargeFileItem] {
        Array(appState.largeFiles.prefix(3))
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Header Bar
            HStack(spacing: 8) {
                AppIconView(size: 26)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("MacSweeper")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("v1.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Storage Guard Active")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: openMainWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Open MacSweeper Window")

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit MacSweeper")
            }

            Divider()

            // Primary Storage Gauge
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Macintosh HD")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(appState.storageOverview.usedPercentage * 100))% Used")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }

                // Storage Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.18))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(appState.storageOverview.usedPercentage)), height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(appState.storageOverview.usedBytes.formattedBytes) used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(appState.storageOverview.freeBytes.formattedBytes) available")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Reclaimable Cache / Quick Sweep Card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safe Reclaimable Junk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appState.safeReclaimableBytes > 0 ? appState.safeReclaimableBytes.formattedBytes : (appState.isScanning ? "Scanning..." : "Clean & Optimized"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(appState.safeReclaimableBytes > 0 ? .green : .primary)
                }

                Spacer()

                Button(action: {
                    appState.quickCleanSafeCaches()
                }) {
                    Label(appState.safeReclaimableBytes > 0 ? "Quick Clean" : "Scan", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(appState.safeReclaimableBytes > 0 ? .green : .accentColor)
                .disabled(appState.isScanning)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Top Large Files Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Big Files Watch", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    if !appState.largeFiles.isEmpty {
                        Text("\(appState.largeFiles.count) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if topLargeFiles.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("No bloated files (>500 MB) detected.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(topLargeFiles) { file in
                            HStack(spacing: 8) {
                                AppIconView(url: file.path, fallbackSystemName: file.kind.systemIcon, size: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text(file.path.deletingLastPathComponent().lastPathComponent)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(file.size.formattedBytes)
                                    .font(.caption)
                                    .fontWeight(.bold)

                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.path])
                                }) {
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // Footer Actions
            HStack(spacing: 10) {
                Button(action: {
                    appState.startComprehensiveScan()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(appState.isScanning ? "Scanning..." : "Refresh Scan")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.isScanning)

                Button(action: openMainWindow) {
                    HStack {
                        Text("Open MacSweeper")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear {
            appState.refreshStorageOverview()
            StorageNotificationService.shared.requestAuthorization()
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "mainWindow" || $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
