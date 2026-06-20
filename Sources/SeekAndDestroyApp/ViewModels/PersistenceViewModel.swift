//
//  PersistenceViewModel.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation
import SeekAndDestroyCore

@MainActor
final class PersistenceViewModel: ObservableObject {
    @Published private(set) var assessments: [PersistenceAssessment] = []
    @Published private(set) var checkedLocations: [PersistenceLocationCheck] = []
    @Published private(set) var statusText = "Ready to scan persistence"
    @Published private(set) var isScanning = false
    @Published private(set) var baselineGeneratedAt: Date?
    @Published private(set) var baselineURL = PersistenceBaselineStore.defaultBaselineURL()
    private var operationTask: Task<Void, Never>?

    var canScan: Bool {
        !isScanning
    }

    var newItemCount: Int {
        assessments.filter { $0.baselineStatus == .new }.count
    }

    var changedItemCount: Int {
        assessments.filter { $0.baselineStatus == .changed }.count
    }

    var knownItemCount: Int {
        assessments.filter { $0.baselineStatus == .known }.count
    }

    var riskFlagCount: Int {
        assessments.reduce(0) { $0 + $1.item.riskFlags.count }
    }

    func scan() {
        guard canScan else {
            return
        }

        isScanning = true
        statusText = "Scanning persistence locations..."

        operationTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                let store = PersistenceBaselineStore()
                let baseline = try? store.load()
                let scanner = PersistenceScanner()
                return scanner.scan(
                    baseline: baseline,
                    shouldCancel: {
                        Task.isCancelled
                    }
                )
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard !Task.isCancelled else {
                statusText = "Persistence scan stopped: partial results shown"
                isScanning = false
                operationTask = nil
                return
            }

            apply(result)
            isScanning = false
            operationTask = nil
        }
    }

    func stopScan() {
        guard isScanning else {
            return
        }

        statusText = "Stopping persistence scan..."
        operationTask?.cancel()
    }

    func saveBaseline() {
        guard !isScanning else {
            return
        }

        isScanning = true
        statusText = "Saving persistence baseline..."

        operationTask = Task {
            let worker = Task.detached(priority: .userInitiated) { () -> Result<PersistenceBaseline, Error> in
                do {
                    let scanner = PersistenceScanner()
                    let baseline = scanner.createBaseline {
                        Task.isCancelled
                    }
                    try PersistenceBaselineStore().save(baseline)
                    return .success(baseline)
                } catch {
                    return .failure(error)
                }
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard !Task.isCancelled else {
                statusText = "Baseline save stopped"
                isScanning = false
                operationTask = nil
                return
            }

            switch result {
            case .success(let baseline):
                baselineGeneratedAt = baseline.generatedAt
                statusText = "Baseline saved with \(baseline.items.count) persistence items"
            case .failure(let error):
                statusText = "Baseline save failed: \(error.localizedDescription)"
            }

            isScanning = false
            operationTask = nil
        }
    }

    private func apply(_ summary: PersistenceScanSummary) {
        assessments = summary.assessedItems.sorted { left, right in
            if left.baselineStatus.sortPriority != right.baselineStatus.sortPriority {
                return left.baselineStatus.sortPriority < right.baselineStatus.sortPriority
            }

            if left.item.riskFlags.count != right.item.riskFlags.count {
                return left.item.riskFlags.count > right.item.riskFlags.count
            }

            return left.item.label.localizedStandardCompare(right.item.label) == .orderedAscending
        }
        checkedLocations = summary.checkedLocations
        baselineGeneratedAt = summary.baselineGeneratedAt

        if summary.isCancelled {
            statusText = "Persistence scan stopped: partial results shown"
        } else if summary.baselineGeneratedAt == nil {
            statusText = "Persistence scan complete: save a baseline to track changes"
        } else if summary.newItemCount + summary.changedItemCount > 0 {
            statusText = "Persistence scan complete: review new or changed items"
        } else {
            statusText = "Persistence scan complete: no baseline changes found"
        }
    }
}

private extension PersistenceBaselineStatus {
    var sortPriority: Int {
        switch self {
        case .new:
            return 0
        case .changed:
            return 1
        case .noBaseline:
            return 2
        case .known:
            return 3
        }
    }
}
