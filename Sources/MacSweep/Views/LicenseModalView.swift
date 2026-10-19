import SwiftUI
import AppKit

public struct LicenseModalView: View {
    @ObservedObject var licenseService = LicenseService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var inputKey: String = ""
    @State private var feedbackMessage: String?
    @State private var isSuccess: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    Text("MacSweep Pro License")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                Button(action: {
                    dismiss()
                }) {
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
                VStack(spacing: 24) {
                    // Status Badge Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                            )

                        VStack(spacing: 8) {
                            HStack {
                                Text(licenseService.isPro ? "LIFETIME PRO ACTIVATED" : "TRIAL MODE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(licenseService.isPro ? Color.green : Color.orange))
                                    .foregroundColor(.white)

                                Spacer()

                                Text(licenseService.isPro ? "One-time purchase · 2 Macs" : "\(licenseService.trialDaysRemaining) days remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(licenseService.isPro ? "All Five Celestial Tools Unlocked" : "Unlock MacSweep Pro")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("Earth Clean, Moon AI Care, Mars Software, Mercury Optimize, Jupiter Treemap, Sun Status, and Menu Bar Runner.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                    }

                    // Key Input Area
                    VStack(alignment: .leading, spacing: 10) {
                        Text("License Key")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            TextField("MOLE-XXXX-XXXX-XXXX or SWEEP-PRO-KEY", text: $inputKey)
                                .textFieldStyle(.roundedBorder)

                            Button("Activate") {
                                let res = licenseService.activate(key: inputKey)
                                isSuccess = res.success
                                feedbackMessage = res.message
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                            .foregroundColor(.black)
                        }

                        if let msg = feedbackMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(isSuccess ? .green : .red)
                        }

                        if licenseService.isPro {
                            HStack {
                                Text("Current Key:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(licenseService.licenseKey)
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(licenseService.licenseKey, forType: .string)
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.blue)

                                Spacer()

                                Button("Deactivate This Mac") {
                                    licenseService.deactivate()
                                    feedbackMessage = "Deactivated this device slot."
                                    isSuccess = true
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))

                    // Registered Devices Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Device Slots (2 of 2 in use)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(licenseService.registeredDevices, id: \.self) { dev in
                            HStack {
                                Image(systemName: "laptopcomputer")
                                    .foregroundColor(.secondary)
                                Text(dev)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Active")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))

                    // Pro Features List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Included in MacSweep Pro:")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        proFeatureRow(icon: "moon.stars.fill", title: "AI Tool Cleanup & Care", desc: "Claude Code, Codex, Cursor, and Ollama deep cache cleaning")
                        proFeatureRow(icon: "bolt.fill", title: "macOS System Optimizer", desc: "Purge memory, reset QuickLook, flush DNS, and vacuum SQLite databases")
                        proFeatureRow(icon: "chart.pie.fill", title: "Interactive Treemap Disk Analyzer", desc: "Proportional tile visualization with instant Finder drill-down")
                        proFeatureRow(icon: "figure.run", title: "Menu Bar Animated Runner", desc: "Custom sprite runners (Mole, Cat, Dog, Rabbit) that speed up with CPU load")
                        proFeatureRow(icon: "fan.fill", title: "Apple Silicon Fan Speed Control", desc: "Auto, Quiet, and Max Cooling Boost modes")
                        proFeatureRow(icon: "wifi", title: "Wi-Fi Low Latency Optimization", desc: "Minimizes jitter and ping spikes for multiplayer gaming and live calls")
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.15), lineWidth: 1))
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button(action: {
                    licenseService.togglePro()
                }) {
                    Text(licenseService.isPro ? "Test Trial Mode" : "Quick Unlock All Features")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 540, minHeight: 620)
        .onAppear {
            inputKey = licenseService.licenseKey
        }
    }

    @ViewBuilder
    private func proFeatureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
