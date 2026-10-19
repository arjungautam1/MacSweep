import SwiftUI

public struct CleanupHistoryView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleanup History & Verification")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Verified record of previous cleanups, measured free space, and restore guidance.")
                        .foregroundColor(.secondary)
                }

                // APFS Storage Information Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Understanding APFS & macOS Trash Storage")
                            .font(.headline)
                    }

                    Text("• **Moving to Trash vs Physical Disk Space**: When items are moved to the Trash, they remain on your APFS volume in an isolated folder. Storage space is physically freed once you choose Finder > 'Empty Trash'.\n• **APFS Clones & Snapshots**: APFS creates zero-cost clones and local Time Machine snapshots. Reclaiming space on disk may be delayed until macOS purges older snapshot differentials.\n• **Restoring**: Items in the Trash can be restored anytime by right-clicking in Trash and clicking 'Put Back'.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.08))
                )

                // History List
                if appState.cleanupHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("No cleanup operations recorded yet.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("When you perform cleanups, detailed logs and measured before/after metrics will be recorded here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(appState.cleanupHistory) { report in
                            ReportHistoryCard(report: report)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

public struct ReportHistoryCard: View {
    public let report: CleanupReport
    @State private var isExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(report.isDryRun ? "Simulation (Dry Run)" : "Clean Completed")
                            .font(.headline)
                            .foregroundColor(report.isDryRun ? .orange : .green)

                        Text(report.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("\(report.successfulItemsCount) items cleaned • \(report.skippedOrFailedCount) skipped/failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(report.estimatedReclaimableBytes.formattedBytes)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Reclaimable")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    withAnimation { isExpanded.toggle() }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Expanded Details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Available Space Before: \(report.preCleanupAvailableBytes.formattedBytes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Available Space After: \(report.postCleanupAvailableBytes.formattedBytes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Itemized Log:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ForEach(report.items.prefix(15)) { item in
                        HStack {
                            Image(systemName: item.status == .movedToTrash ? "trash" : "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(item.status.rawValue)
                                .font(.caption2)
                                .foregroundColor(item.status == .failed ? .red : .secondary)
                            Text(item.originalSize.formattedBytes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if report.items.count > 15 {
                        Text("... and \(report.items.count - 15) more items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
