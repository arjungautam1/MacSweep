import SwiftUI
import AppKit

public struct StatusView: View {
    @ObservedObject var appState: AppState
    @StateObject private var telemetry = SystemTelemetryService.shared
    @State private var processSearch: String = ""

    public init(appState: AppState = AppState.shared) {
        self.appState = appState
    }

    private var filteredProcesses: [ProcessInfoItem] {
        if processSearch.isEmpty {
            return telemetry.topProcesses
        }
        return telemetry.topProcesses.filter {
            $0.name.localizedCaseInsensitiveContains(processSearch) ||
            $0.plainExplanation.localizedCaseInsensitiveContains(processSearch)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Celestial Hero Header
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.12), Color.red.opacity(0.06), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                        )

                    HStack(spacing: 24) {
                        // Sun Visual
                        ZStack {
                            Circle()
                                .fill(RadialGradient(
                                    colors: [Color.orange.opacity(0.4), Color.clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 70
                                ))
                                .frame(width: 140, height: 140)

                            if let sunImg = AssetLoader.loadNSImage(named: "planet-static-sun") {
                                Image(nsImage: sunImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .orange.opacity(0.4), radius: 14, x: 0, y: 4)
                            } else {
                                Image(systemName: "sun.max.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.orange)
                            }
                        }

                        // Hero Text & Controls
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("The Sun watches Status")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()

                                // Fan Mode Control
                                Picker("Fan Mode", selection: Binding(
                                    get: { telemetry.fanMode },
                                    set: { telemetry.setFanMode($0) }
                                )) {
                                    ForEach(FanMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 220)
                            }

                            Text(NavigationSection.status.poem)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .italic()

                            Divider()
                                .padding(.vertical, 4)

                            // Quick Toggles (Keep Awake)
                            HStack(spacing: 12) {
                                Text("Keep Screen Awake:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ForEach(KeepAwakeDuration.allCases) { duration in
                                    Button(action: {
                                        telemetry.setKeepAwake(duration)
                                    }) {
                                        Text(duration.rawValue)
                                            .font(.caption2)
                                            .fontWeight(telemetry.keepAwakeDuration == duration ? .bold : .regular)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule().fill(telemetry.keepAwakeDuration == duration ? Color.orange : Color.gray.opacity(0.18))
                                            )
                                            .foregroundColor(telemetry.keepAwakeDuration == duration ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                // Hardware Telemetry Grid (6 Tiles)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    telemetryCard(
                        title: "CPU Load",
                        value: String(format: "%.1f%%", telemetry.cpuUsagePercentage),
                        subtitle: "\(telemetry.cpuCoreCount) Cores · \(String(format: "%.1f°C", telemetry.cpuTemperatureCelsius))",
                        icon: "cpu",
                        color: .blue,
                        progress: telemetry.cpuUsagePercentage / 100.0
                    )

                    telemetryCard(
                        title: "Memory Used",
                        value: telemetry.memoryUsedBytes.formattedBytes,
                        subtitle: "Total \(telemetry.memoryTotalBytes.formattedBytes) · \(telemetry.memoryPressure)",
                        icon: "memorychip",
                        color: .purple,
                        progress: Double(telemetry.memoryUsedBytes) / Double(max(1, telemetry.memoryTotalBytes))
                    )

                    telemetryCard(
                        title: "Disk I/O",
                        value: String(format: "%.1f MB/s", telemetry.diskReadSpeedMB + telemetry.diskWriteSpeedMB),
                        subtitle: "Read: \(String(format: "%.1f", telemetry.diskReadSpeedMB)) · Write: \(String(format: "%.1f", telemetry.diskWriteSpeedMB))",
                        icon: "internaldrive",
                        color: .teal,
                        progress: min(1.0, (telemetry.diskReadSpeedMB + telemetry.diskWriteSpeedMB) / 20.0)
                    )

                    telemetryCard(
                        title: "Network Activity",
                        value: String(format: "↓ %.1f KB/s", telemetry.netDownloadKBs),
                        subtitle: String(format: "↑ %.1f KB/s", telemetry.netUploadKBs),
                        icon: "network",
                        color: .green,
                        progress: min(1.0, telemetry.netDownloadKBs / 200.0)
                    )

                    telemetryCard(
                        title: "Battery Health",
                        value: "\(telemetry.batteryPercentage)%",
                        subtitle: "\(telemetry.isBatteryCharging ? "Charging" : "Discharging") · \(telemetry.batteryCycleCount) Cycles",
                        icon: "battery.100.bolt",
                        color: .yellow,
                        progress: Double(telemetry.batteryPercentage) / 100.0
                    )

                    telemetryCard(
                        title: "Fan & Thermals",
                        value: "\(telemetry.fanRPM) RPM",
                        subtitle: "Mode: \(telemetry.fanMode.rawValue) · \(String(format: "%.1f°C", telemetry.cpuTemperatureCelsius))",
                        icon: "fan.fill",
                        color: .orange,
                        progress: Double(telemetry.fanRPM) / 5000.0
                    )
                }

                // Live Process Monitor Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Active Process Monitor")
                                .font(.headline)
                            Text("Top resource-consuming background and system processes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("Sort by", selection: $telemetry.processSortByCPU) {
                            Text("CPU %").tag(true)
                            Text("Memory").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)

                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Filter processes...", text: $processSearch)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                        .frame(width: 180)
                    }

                    // Process Table
                    VStack(spacing: 0) {
                        ForEach(filteredProcesses) { p in
                            HStack(spacing: 12) {
                                AppIconView(fallbackSystemName: "app.fill", size: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(p.name)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                        Text("PID: \(p.id)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("User: \(p.user)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(p.plainExplanation)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.1f%% CPU", p.cpuPercentage))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(p.cpuPercentage > 20 ? .orange : .primary)
                                    Text(p.memoryFormatted)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Button("Quit") {
                                    telemetry.terminateProcess(pid: p.id, force: false)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            if p.id != filteredProcesses.last?.id {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func telemetryCard(title: String, value: String, subtitle: String, icon: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.18))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, progress)))), height: 6)
                }
            }
            .frame(height: 6)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
    }
}
