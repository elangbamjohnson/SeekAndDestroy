//
//  ScanViewModel.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation
import SeekAndDestroyCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var scannedFileCount = 0
    @Published private(set) var skippedFileCount = 0
    @Published private(set) var scannedFileItems: [LiveFileItem] = []
    @Published private(set) var skippedFileItems: [LiveFileItem] = []
    @Published private(set) var findings: [ScanFinding] = []
    @Published private(set) var statusText = "Ready to scan"
    @Published private(set) var isScanning = false
    @Published var scanDesktop = true
    @Published var scanDownloads = true
    @Published var scanApplications = true

    private let threatDatabase: HashThreatDatabase
    private let maxVisibleFileEvents = 200
    private var scanTask: Task<Void, Never>?

    init() {
        do {
            self.threatDatabase = try HashThreatDatabase.loadBundled()
        } catch {
            self.threatDatabase = HashThreatDatabase(threats: [])
            self.statusText = "Threat database failed to load"
        }
    }

    var selectedDirectories: [URL] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        var directories: [URL] = []

        if scanDownloads {
            directories.append(homeDirectory.appendingPathComponent("Downloads"))
        }

        if scanDesktop {
            directories.append(homeDirectory.appendingPathComponent("Desktop"))
        }

        if scanApplications {
            directories.append(URL(fileURLWithPath: "/Applications"))
        }

        return directories
    }

    var canScan: Bool {
        !isScanning && !selectedDirectories.isEmpty
    }

    func scan() {
        guard canScan else {
            return
        }

        isScanning = true
        statusText = "Scanning..."
        scannedFileCount = 0
        skippedFileCount = 0
        scannedFileItems = []
        skippedFileItems = []
        findings = []

        let directories = selectedDirectories
        let database = threatDatabase

        scanTask = Task {
            let updates = AsyncStream<ScannerUpdate> { continuation in
                let worker = Task.detached(priority: .userInitiated) {
                    let scanner = OnDemandScanner(threatDatabase: database)
                    let summary = scanner.scan(
                        directories: directories,
                        progressHandler: { event in
                            continuation.yield(.progress(event))
                        },
                        shouldCancel: {
                            Task.isCancelled
                        }
                    )

                    continuation.yield(.completed(summary))
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    worker.cancel()
                }
            }

            for await update in updates {
                guard !Task.isCancelled else {
                    break
                }

                switch update {
                case .progress(let event):
                    handleProgressEvent(event)
                case .completed(let summary):
                    applyCompletedSummary(summary)
                }
            }

            if Task.isCancelled {
                finishStoppedScan()
            }
        }
    }

    func stopScan() {
        guard isScanning else {
            return
        }

        statusText = "Stopping scan..."
        scanTask?.cancel()
    }

    private func handleProgressEvent(_ event: ScanProgressEvent) {
        switch event {
        case .scannedFile(let url):
            scannedFileCount += 1
            appendVisibleItem(LiveFileItem(url: url), to: \.scannedFileItems)
            statusText = "Scanning: \(url.lastPathComponent)"
        case .skippedFile(let url):
            skippedFileCount += 1
            appendVisibleItem(LiveFileItem(url: url), to: \.skippedFileItems)
        case .finding(let finding):
            findings.append(finding)
            statusText = "Finding found: \(finding.fileURL.lastPathComponent)"
        }
    }

    private func applyCompletedSummary(_ summary: ScanSummary) {
        scannedFileCount = summary.scannedFileCount
        skippedFileCount = summary.skippedFileCount
        scannedFileItems = summary.scannedFiles.suffix(maxVisibleFileEvents).map(LiveFileItem.init(url:))
        skippedFileItems = summary.skippedFiles.suffix(maxVisibleFileEvents).map(LiveFileItem.init(url:))
        findings = summary.findings
        if summary.isCancelled {
            statusText = "Scan stopped: partial results shown"
        } else {
            statusText = summary.findings.isEmpty ? "Scan complete: no hash matches found" : "Scan complete: findings require review"
        }
        isScanning = false
        scanTask = nil
    }

    private func finishStoppedScan() {
        statusText = "Scan stopped: partial results shown"
        isScanning = false
        scanTask = nil
    }

    private func appendVisibleItem(_ item: LiveFileItem, to keyPath: ReferenceWritableKeyPath<ScanViewModel, [LiveFileItem]>) {
        self[keyPath: keyPath].append(item)

        if self[keyPath: keyPath].count > maxVisibleFileEvents {
            self[keyPath: keyPath].removeFirst(self[keyPath: keyPath].count - maxVisibleFileEvents)
        }
    }
}

struct LiveFileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

private enum ScannerUpdate: Sendable {
    case progress(ScanProgressEvent)
    case completed(ScanSummary)
}
