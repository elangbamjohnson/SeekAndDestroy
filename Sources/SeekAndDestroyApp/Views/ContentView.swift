//
//  ContentView.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import SeekAndDestroyCore
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()
    @StateObject private var persistenceViewModel = PersistenceViewModel()
    @State private var selectedSection = AppSection.fileScan

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(alignment: .top, spacing: 0) {
                sidebar

                Divider()

                resultsPane
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Seek And Destroy")
                    .font(.title2.weight(.semibold))
                Text(headerStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: primaryAction) {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
                    .frame(minWidth: 92)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canRunPrimaryAction)

            if isActiveOperationRunning {
                Button(action: stopActiveOperation) {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 76)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mode")
                    .font(.headline)

                Picker("Mode", selection: $selectedSection) {
                    Text("File Scan").tag(AppSection.fileScan)
                    Text("Persistence").tag(AppSection.persistence)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Scan Locations")
                    .font(.headline)

                Toggle("Downloads", isOn: $viewModel.scanDownloads)
                Toggle("Desktop", isOn: $viewModel.scanDesktop)
                Toggle("Applications", isOn: $viewModel.scanApplications)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Security Signals")
                    .font(.headline)

                signalRow(icon: "number", title: "SHA-256 hash", value: "Enabled")
                signalRow(icon: "doc.text.magnifyingglass", title: "Local hash list", value: "Enabled")
                signalRow(icon: "lock.doc", title: "Persistence", value: "Enabled")
                signalRow(icon: "checkmark.seal", title: "Code signing", value: "Next")
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 260, alignment: .topLeading)
    }

    @ViewBuilder
    private var resultsPane: some View {
        switch selectedSection {
        case .fileScan:
            fileScanPane
        case .persistence:
            PersistenceView(viewModel: persistenceViewModel)
        }
    }

    private var fileScanPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                metric(title: "Scanned", value: viewModel.scannedFileCount.formatted(), icon: "doc")
                metric(title: "Skipped", value: viewModel.skippedFileCount.formatted(), icon: "exclamationmark.triangle")
                metric(title: "Findings", value: viewModel.findings.count.formatted(), icon: "cross.case")
            }

            if viewModel.isScanning {
                scanningState
            }

            activityColumns
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scanningState: some View {
        HStack(spacing: 12) {
            HourglassSpinner()

            VStack(alignment: .leading, spacing: 4) {
                Text("Scanning")
                    .font(.headline)
                Text("Walking selected directories and hashing readable files")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProgressView()
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var activityColumns: some View {
        HStack(alignment: .top, spacing: 12) {
            LiveFileColumn(
                title: "Scanned",
                icon: "doc",
                count: viewModel.scannedFileCount,
                emptyText: viewModel.isScanning ? "Waiting for first readable file" : "No files scanned yet"
            ) {
                ForEach(viewModel.scannedFileItems) { item in
                    FilePathRow(url: item.url, tint: .blue)
                }
            }

            LiveFileColumn(
                title: "Skipped",
                icon: "exclamationmark.triangle",
                count: viewModel.skippedFileCount,
                emptyText: viewModel.isScanning ? "No skipped files so far" : "No skipped files"
            ) {
                ForEach(viewModel.skippedFileItems) { item in
                    FilePathRow(url: item.url, tint: .orange)
                }
            }

            LiveFileColumn(
                title: "Findings",
                icon: "cross.case",
                count: viewModel.findings.count,
                emptyText: viewModel.isScanning ? "No findings so far" : "No malicious hash matches found"
            ) {
                ForEach(viewModel.findings, id: \.fileURL) { finding in
                    FindingRow(finding: finding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.blue)

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
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func signalRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(value == "Next" ? .orange : .green)
        }
        .font(.callout)
    }

    private var headerStatusText: String {
        switch selectedSection {
        case .fileScan:
            return viewModel.statusText
        case .persistence:
            return persistenceViewModel.statusText
        }
    }

    private var primaryActionTitle: String {
        switch selectedSection {
        case .fileScan:
            return viewModel.isScanning ? "Scanning" : "Scan"
        case .persistence:
            return persistenceViewModel.isScanning ? "Scanning" : "Scan Persistence"
        }
    }

    private var primaryActionIcon: String {
        switch selectedSection {
        case .fileScan:
            return viewModel.isScanning ? "hourglass" : "magnifyingglass"
        case .persistence:
            return persistenceViewModel.isScanning ? "hourglass" : "lock.doc"
        }
    }

    private var canRunPrimaryAction: Bool {
        switch selectedSection {
        case .fileScan:
            return viewModel.canScan
        case .persistence:
            return persistenceViewModel.canScan
        }
    }

    private var isActiveOperationRunning: Bool {
        switch selectedSection {
        case .fileScan:
            return viewModel.isScanning
        case .persistence:
            return persistenceViewModel.isScanning
        }
    }

    private func primaryAction() {
        switch selectedSection {
        case .fileScan:
            viewModel.scan()
        case .persistence:
            persistenceViewModel.scan()
        }
    }

    private func stopActiveOperation() {
        switch selectedSection {
        case .fileScan:
            viewModel.stopScan()
        case .persistence:
            persistenceViewModel.stopScan()
        }
    }
}

struct HourglassSpinner: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let rotation = elapsed.truncatingRemainder(dividingBy: 1.2) / 1.2 * 360

            Image(systemName: "hourglass")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(rotation))
                .frame(width: 64, height: 64)
                .accessibilityLabel("Scanning")
        }
    }
}

private enum AppSection {
    case fileScan
    case persistence
}

private struct LiveFileColumn<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    let emptyText: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(count.formatted())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if count == 0 {
                        Text(emptyText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    } else {
                        content
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FilePathRow: View {
    let url: URL
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc")
                .font(.callout)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FindingRow: View {
    let finding: ScanFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: "exclamationmark.octagon.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Spacer()
                Text("SHA-256")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(finding.fileURL.path)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)

            Text(finding.sha256)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }

    private var title: String {
        switch finding.kind {
        case .maliciousHash(let threat):
            return threat.name
        }
    }
}
