import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @StateObject private var runnerService = MenuBarRunnerService.shared
    @StateObject private var telemetry = SystemTelemetryService.shared
    @StateObject private var license = LicenseService.shared

    @State private var showThemePicker: Bool = false

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack(spacing: 8) {
                // Clean Brush / Sweeper Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("MacSweep")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("PRO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text(String(format: "%.1f%% CPU · %.1f°C", telemetry.cpuUsagePercentage, telemetry.cpuTemperatureCelsius))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Theme Switcher Button
                Button(action: {
                    showThemePicker.toggle()
                }) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(showThemePicker ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help("Switch Menu Bar Runner Sprite")

                // Open Main Window
                Button(action: openMainWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open MacSweep Window")

                // Quit App
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit MacSweep")
            }

            // Runner Theme Picker Dropdown
            if showThemePicker {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Menu Bar Runner & Display Mode")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Picker("Runner", selection: Binding(
                        get: { runnerService.currentTheme },
                        set: { runnerService.setTheme($0) }
                    )) {
                        ForEach(RunnerTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Mode", selection: Binding(
                        get: { runnerService.displayMode },
                        set: { runnerService.setDisplayMode($0) }
                    )) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            }

            Divider()

            // Keep Screen Awake / Caffeinate Strip
            HStack(spacing: 8) {
                Image(systemName: telemetry.keepAwakeDuration != .off ? "sun.max.fill" : "moon.fill")
                    .font(.caption)
                    .foregroundColor(telemetry.keepAwakeDuration != .off ? .orange : .secondary)

                Text("Keep Awake:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                ForEach(KeepAwakeDuration.allCases) { duration in
                    Button(action: {
                        telemetry.setKeepAwake(duration)
                    }) {
                        Text(duration.rawValue)
                            .font(.caption2)
                            .fontWeight(telemetry.keepAwakeDuration == duration ? .bold : .regular)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(telemetry.keepAwakeDuration == duration ? Color.orange : Color.gray.opacity(0.15))
                            )
                            .foregroundColor(telemetry.keepAwakeDuration == duration ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Hardware Telemetry Glance (4 Compact Pills)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                // CPU & Fan
                HStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "CPU %.1f%%", telemetry.cpuUsagePercentage))
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("\(telemetry.fanRPM) RPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

                // Memory & Pressure
                HStack(spacing: 8) {
                    Image(systemName: "memorychip")
                        .foregroundColor(.purple)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(telemetry.memoryUsedBytes.formattedBytes)
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("\(telemetry.memoryPressure) Pressure")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

                // Storage Free
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.teal)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.storageOverview.freeBytes.formattedBytes)
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Available")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

                // Network
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .foregroundColor(.green)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "↓ %.0f KB/s", telemetry.netDownloadKBs))
                            .font(.caption)
                            .fontWeight(.bold)
                        Text(String(format: "↑ %.0f KB/s", telemetry.netUploadKBs))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            }

            // Quick Clean Reclaimable Card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleanable Junk")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(appState.safeReclaimableBytes > 0 ? appState.safeReclaimableBytes.formattedBytes : (appState.isScanning ? "Scanning..." : "System Clean"))
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
                .tint(appState.safeReclaimableBytes > 0 ? .blue : .accentColor)
                .disabled(appState.isScanning)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

            // Top Processes Strip
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Top Processes")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                VStack(spacing: 4) {
                    ForEach(telemetry.topProcesses.prefix(3)) { p in
                        HStack(spacing: 8) {
                            Text(p.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Spacer()

                            Text(String(format: "%.1f%%", p.cpuPercentage))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(p.cpuPercentage > 15 ? .orange : .secondary)

                            Text(p.memoryFormatted)
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Button(action: {
                                telemetry.terminateProcess(pid: p.id, force: false)
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Quit process")
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

            Divider()

            // Bottom Actions
            HStack(spacing: 10) {
                Button(action: {
                    appState.showAICleanupView = true
                    openMainWindow()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.purple)
                        Text("AI Tool Care")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: openMainWindow) {
                    HStack {
                        Text("Open MacSweep")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 340)
        .onAppear {
            appState.refreshStorageOverview()
            telemetry.refreshMetrics()
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
