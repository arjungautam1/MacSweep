import SwiftUI

public struct CleanupReportSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    public var report: CleanupReport? {
        appState.currentReport
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report?.isDryRun == true ? "Simulation Complete" : "Cleanup Complete")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Verified execution report and measured disk results.")
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
                    // Permission / Failure Notice Banner
                    if (report?.items.contains { $0.status == .failed } == true) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Some Items Require Full Disk Access")
                                    .fontWeight(.bold)
                                Text("macOS restricts modifying or deleting files in protected directories (e.g. ~/Library/Safari, Mail, Containers) without explicit Full Disk Access. Grant Full Disk Access in macOS System Settings and retry cleanup.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button("Open Full Disk Access Settings") {
                                    DiskPermissionService.shared.openFullDiskAccessSettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .padding(.top, 2)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.12))
                        )
                    }

                    // Result Metrics
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Space Reclaimable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(report?.estimatedReclaimableBytes.formattedBytes ?? "0 B")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Successful Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(report?.successfulItemsCount ?? 0) of \(report?.items.count ?? 0)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                    )

                    // Disk Free Space Comparison
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Measured Boot Volume Available Capacity")
                            .font(.headline)

                        HStack {
                            Text("Before: \(report?.preCleanupAvailableBytes.formattedBytes ?? "0 B")")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("After: \(report?.postCleanupAvailableBytes.formattedBytes ?? "0 B")")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                    // Restore Instructions
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundColor(.blue)
                            Text("How to Restore Items from Trash")
                                .font(.headline)
                        }
                        Text(report?.restoreInstructions ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.08))
                    )

                    // Itemized Results
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Itemized Results:")
                            .font(.headline)

                        if let items = report?.items {
                            ForEach(items) { item in
                                HStack {
                                    Image(systemName: item.status == .failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                        .foregroundColor(item.status == .failed ? .red : .green)
                                        .font(.caption)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        if let err = item.errorMessage {
                                            Text(err)
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        }
                                    }

                                    Spacer()

                                    Text(item.status.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Text(item.originalSize.formattedBytes)
                                        .font(.caption)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 500, minHeight: 480)
    }
}
