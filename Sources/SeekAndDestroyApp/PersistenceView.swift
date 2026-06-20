//
//  PersistenceView.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import SeekAndDestroyCore
import SwiftUI

struct PersistenceView: View {
    @ObservedObject var viewModel: PersistenceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                metric(title: "New", value: viewModel.newItemCount.formatted(), icon: "plus.circle", tint: .red)
                metric(title: "Changed", value: viewModel.changedItemCount.formatted(), icon: "arrow.triangle.2.circlepath", tint: .orange)
                metric(title: "Known", value: viewModel.knownItemCount.formatted(), icon: "checkmark.circle", tint: .green)
                metric(title: "Risk Flags", value: viewModel.riskFlagCount.formatted(), icon: "flag", tint: .purple)
            }

            HStack(spacing: 10) {
                Button(action: viewModel.scan) {
                    Label(viewModel.isScanning ? "Scanning" : "Scan Persistence", systemImage: viewModel.isScanning ? "hourglass" : "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canScan)

                Button(action: viewModel.saveBaseline) {
                    Label("Save Baseline", systemImage: "tray.and.arrow.down")
                }
                .disabled(viewModel.isScanning)

                if viewModel.isScanning {
                    Button(action: viewModel.stopScan) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .keyboardShortcut(.cancelAction)
                }

                Spacer()

                if let generatedAt = viewModel.baselineGeneratedAt {
                    Text("Baseline: \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No baseline loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isScanning {
                HStack(spacing: 12) {
                    HourglassSpinner()
                    Text(viewModel.statusText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(alignment: .top, spacing: 12) {
                persistenceItemsPanel
                checkedLocationsPanel
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var persistenceItemsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Persistence Items")
                .font(.headline)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if viewModel.assessments.isEmpty {
                        Text("Run a persistence scan to inspect LaunchAgents, LaunchDaemons, cron, and periodic scripts.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.assessments) { assessment in
                            PersistenceAssessmentRow(assessment: assessment)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var checkedLocationsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Locations Checked")
                .font(.headline)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.checkedLocations) { check in
                        LocationCheckRow(check: check)
                    }

                    if viewModel.checkedLocations.isEmpty {
                        Text("No locations checked yet")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PersistenceAssessmentRow: View {
    let assessment: PersistenceAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(assessment.item.label)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(assessment.baselineStatus.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 8) {
                Label(assessment.item.kind.rawValue, systemImage: "gearshape")
                if !assessment.item.riskFlags.isEmpty {
                    Label("\(assessment.item.riskFlags.count) flags", systemImage: "flag.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let executablePath = assessment.item.executablePath {
                Text(executablePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if let sourcePath = assessment.item.sourceURL?.path {
                Text(sourcePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if let details = assessment.item.launchdDetails, details.hasDisplayedValues {
                LaunchdDetailsBlock(details: details)
            }

            if !assessment.item.riskFlags.isEmpty {
                Text(assessment.item.riskFlags.map(\.title).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch assessment.baselineStatus {
        case .new:
            return .red
        case .changed:
            return .orange
        case .known:
            return .green
        case .noBaseline:
            return .secondary
        }
    }
}

private struct LaunchdDetailsBlock: View {
    let details: LaunchdDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let runAtLoad = details.runAtLoad {
                detailLine("RunAtLoad", runAtLoad ? "true" : "false")
            }

            if let keepAlive = details.keepAlive {
                detailLine("KeepAlive", keepAlive.displaySummary)
            }

            if let startInterval = details.startInterval {
                detailLine("StartInterval", "\(startInterval)s")
            }

            if !details.startCalendarIntervals.isEmpty {
                detailLine("StartCalendarInterval", details.startCalendarIntervals.joined(separator: " | "))
            }

            if !details.watchPaths.isEmpty {
                detailLine("WatchPaths", details.watchPaths.joined(separator: ", "))
            }

            if !details.queueDirectories.isEmpty {
                detailLine("QueueDirectories", details.queueDirectories.joined(separator: ", "))
            }

            if !details.machServices.isEmpty {
                detailLine("MachServices", details.machServices.joined(separator: ", "))
            }

            if !details.sockets.isEmpty {
                detailLine("Sockets", details.sockets.joined(separator: ", "))
            }

            if let standardOutPath = details.standardOutPath {
                detailLine("StandardOutPath", standardOutPath)
            }

            if let standardErrorPath = details.standardErrorPath {
                detailLine("StandardErrorPath", standardErrorPath)
            }

            if let workingDirectory = details.workingDirectory {
                detailLine("WorkingDirectory", workingDirectory)
            }

            if !details.environmentVariables.isEmpty {
                let variables = details.environmentVariables.keys
                    .sorted()
                    .map { "\($0)=\(details.environmentVariables[$0] ?? "")" }
                    .joined(separator: ", ")
                detailLine("Environment", variables)
            }
        }
        .padding(.top, 2)
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

private struct LocationCheckRow: View {
    let check: PersistenceLocationCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(check.title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(check.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            if let path = check.url?.path {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            if check.itemCount > 0 {
                Text("\(check.itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private var statusColor: Color {
        switch check.status {
        case .scanned:
            return .green
        case .missing:
            return .secondary
        case .unreadable:
            return .orange
        case .bestEffort:
            return .blue
        }
    }
}
