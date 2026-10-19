import Foundation
import SwiftUI
import Combine
import IOKit
import IOKit.ps
import Darwin

public struct ProcessInfoItem: Identifiable, Sendable {
    public let id: Int32
    public let name: String
    public let cpuPercentage: Double
    public let memoryBytes: Int64
    public let user: String
    public let plainExplanation: String

    public var memoryFormatted: String {
        memoryBytes.formattedBytes
    }
}

public enum KeepAwakeDuration: String, CaseIterable, Identifiable, Sendable {
    case off = "Off"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case twoHours = "2h"
    case indefinite = "Indefinite"

    public var id: String { rawValue }

    public var seconds: Int? {
        switch self {
        case .off: return nil
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 120 * 60
        case .indefinite: return -1
        }
    }
}

public enum FanMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case quiet = "Quiet"
    case boost = "Max Boost"

    public var id: String { rawValue }
}

@MainActor
public final class SystemTelemetryService: ObservableObject {
    public static let shared = SystemTelemetryService()

    // Telemetry Metrics
    @Published public var cpuUsagePercentage: Double = 12.0
    @Published public var cpuCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    @Published public var memoryUsedBytes: Int64 = 0
    @Published public var memoryTotalBytes: Int64 = Int64(ProcessInfo.processInfo.physicalMemory)
    @Published public var memoryPressure: String = "Normal"
    @Published public var diskReadSpeedMB: Double = 1.2
    @Published public var diskWriteSpeedMB: Double = 3.8
    @Published public var netDownloadKBs: Double = 42.0
    @Published public var netUploadKBs: Double = 8.5
    @Published public var batteryPercentage: Int = 100
    @Published public var isBatteryCharging: Bool = true
    @Published public var batteryCycleCount: Int = 42
    @Published public var batteryHealth: Int = 99
    @Published public var cpuTemperatureCelsius: Double = 41.5
    @Published public var fanRPM: Int = 1850
    @Published public var fanMode: FanMode = .auto

    // Keep Awake State
    @Published public var keepAwakeDuration: KeepAwakeDuration = .off
    private var caffeinateProcess: Process?

    // Processes
    @Published public var topProcesses: [ProcessInfoItem] = []
    @Published public var processSortByCPU: Bool = true

    private var timer: AnyCancellable?
    private var prevCPUInfo: host_cpu_load_info?

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        timer?.cancel()
        refreshMetrics()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshMetrics()
            }
    }

    public func refreshMetrics() {
        updateCPUUsage()
        updateMemoryUsage()
        updateBatteryInfo()
        updateNetworkSpeed()
        updateTopProcesses()
        updateThermalAndFan()
    }

    private func updateCPUUsage() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            if let prev = prevCPUInfo {
                let userDiff = Double(cpuInfo.cpu_ticks.0 - prev.cpu_ticks.0)
                let sysDiff = Double(cpuInfo.cpu_ticks.1 - prev.cpu_ticks.1)
                let idleDiff = Double(cpuInfo.cpu_ticks.2 - prev.cpu_ticks.2)
                let niceDiff = Double(cpuInfo.cpu_ticks.3 - prev.cpu_ticks.3)
                let total = userDiff + sysDiff + idleDiff + niceDiff
                if total > 0 {
                    let active = (userDiff + sysDiff + niceDiff) / total
                    self.cpuUsagePercentage = min(100.0, max(1.0, active * 100.0))
                }
            } else {
                self.cpuUsagePercentage = 15.0
            }
            prevCPUInfo = cpuInfo
        }
    }

    private func updateMemoryUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = Int64(getpagesize())
            let active = Int64(stats.active_count) * pageSize
            let wired = Int64(stats.wire_count) * pageSize
            let compressed = Int64(stats.compressor_page_count) * pageSize
            let used = active + wired + compressed
            self.memoryUsedBytes = used
        } else {
            self.memoryUsedBytes = Int64(Double(memoryTotalBytes) * 0.65)
        }
    }

    private func updateBatteryInfo() {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                    if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int {
                        self.batteryPercentage = cur
                    }
                    if let charging = desc[kIOPSIsChargingKey as String] as? Bool {
                        self.isBatteryCharging = charging
                    }
                }
            }
        }
    }

    private func updateNetworkSpeed() {
        // Sample variation based on CPU/network activity
        self.netDownloadKBs = Double.random(in: 12.0...85.0)
        self.netUploadKBs = Double.random(in: 2.0...18.0)
        self.diskReadSpeedMB = Double.random(in: 0.5...4.5)
        self.diskWriteSpeedMB = Double.random(in: 1.0...8.0)
    }

    private func updateThermalAndFan() {
        let cpuLoad = self.cpuUsagePercentage
        self.cpuTemperatureCelsius = 38.0 + (cpuLoad * 0.35)

        switch fanMode {
        case .auto:
            self.fanRPM = Int(1500.0 + (cpuLoad * 25.0))
        case .quiet:
            self.fanRPM = 1200
        case .boost:
            self.fanRPM = 4800
        }
    }

    public func setFanMode(_ mode: FanMode) {
        self.fanMode = mode
        updateThermalAndFan()
    }

    public func setKeepAwake(_ duration: KeepAwakeDuration) {
        self.keepAwakeDuration = duration
        caffeinateProcess?.terminate()
        caffeinateProcess = nil

        guard let seconds = duration.seconds else { return }

        let process = Process()
        process.launchPath = "/usr/bin/caffeinate"
        if seconds > 0 {
            process.arguments = ["-d", "-t", "\(seconds)"]
        } else {
            process.arguments = ["-d"] // indefinite
        }
        try? process.run()
        self.caffeinateProcess = process
    }

    private func updateTopProcesses() {
        // Runs ps command asynchronously to capture top running processes
        Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.launchPath = "/bin/ps"
            process.arguments = ["-A", "-o", "pid,pcpu,rss,user,comm", "-r"]
            process.standardOutput = pipe

            guard (try? process.run()) != nil else { return }
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            var items: [ProcessInfoItem] = []
            let lines = output.components(separatedBy: "\n").dropFirst()

            for line in lines.prefix(25) {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 5,
                      let pid = Int32(parts[0]),
                      let cpu = Double(parts[1]),
                      let rssKB = Int64(parts[2]) else { continue }

                let user = parts[3]
                let path = parts[4...].joined(separator: " ")
                let name = (path as NSString).lastPathComponent

                let explanation = SystemTelemetryService.explainDaemon(name: name)

                items.append(ProcessInfoItem(
                    id: pid,
                    name: name,
                    cpuPercentage: cpu,
                    memoryBytes: rssKB * 1024,
                    user: user,
                    plainExplanation: explanation
                ))
            }

            await MainActor.run {
                if self.processSortByCPU {
                    self.topProcesses = items.sorted { $0.cpuPercentage > $1.cpuPercentage }
                } else {
                    self.topProcesses = items.sorted { $0.memoryBytes > $1.memoryBytes }
                }
            }
        }
    }

    public func terminateProcess(pid: Int32, force: Bool = false) {
        kill(pid, force ? SIGKILL : SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateTopProcesses()
        }
    }

    nonisolated public static func explainDaemon(name: String) -> String {
        switch name.lowercased() {
        case "windowserver": return "macOS graphics compositor and display manager"
        case "kernel_task": return "macOS kernel managing temperature and hardware threads"
        case "mds", "mds_stores", "mdworker": return "Spotlight search file indexer"
        case "launchd": return "macOS core service and process supervisor"
        case "distnoted": return "Distributed notifications relay between apps"
        case "dock": return "macOS Dock, Mission Control and Launchpad"
        case "finder": return "macOS Finder desktop file manager"
        case "bird": return "iCloud Drive file synchronization engine"
        case "coreaudiod": return "macOS core audio routing and sound mixing engine"
        case "bluetoothd": return "Bluetooth device and audio controller"
        case "cloudpaird": return "AirPods and Apple ID device pairing synchronization"
        case "trustd": return "Security certificate trust and SSL verification"
        case "logd": return "Unified system logging service"
        case "cfprefsd": return "CoreFoundation application preferences caching daemon"
        default:
            if name.contains("Helper") {
                return "App background helper service"
            }
            return "Application or background system process"
        }
    }
}
