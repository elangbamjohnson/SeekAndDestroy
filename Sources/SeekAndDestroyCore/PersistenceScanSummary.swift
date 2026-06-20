//
//  PersistenceScanSummary.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct PersistenceScanSummary: Equatable, Sendable {
    public let assessedItems: [PersistenceAssessment]
    public let checkedLocations: [PersistenceLocationCheck]
    public let baselineGeneratedAt: Date?
    public let isCancelled: Bool

    public init(
        assessedItems: [PersistenceAssessment],
        checkedLocations: [PersistenceLocationCheck],
        baselineGeneratedAt: Date?,
        isCancelled: Bool = false
    ) {
        self.assessedItems = assessedItems
        self.checkedLocations = checkedLocations
        self.baselineGeneratedAt = baselineGeneratedAt
        self.isCancelled = isCancelled
    }

    public var newItemCount: Int {
        assessedItems.filter { $0.baselineStatus == .new }.count
    }

    public var changedItemCount: Int {
        assessedItems.filter { $0.baselineStatus == .changed }.count
    }

    public var knownItemCount: Int {
        assessedItems.filter { $0.baselineStatus == .known }.count
    }

    public var riskFlagCount: Int {
        assessedItems.reduce(0) { $0 + $1.item.riskFlags.count }
    }
}

public struct PersistenceAssessment: Equatable, Identifiable, Sendable {
    public let id: String
    public let item: PersistenceItem
    public let baselineStatus: PersistenceBaselineStatus

    public init(item: PersistenceItem, baselineStatus: PersistenceBaselineStatus) {
        self.id = item.id
        self.item = item
        self.baselineStatus = baselineStatus
    }
}

public enum PersistenceBaselineStatus: String, Codable, Sendable {
    case noBaseline = "No Baseline"
    case known = "Known"
    case new = "New"
    case changed = "Changed"
}

public struct PersistenceLocationCheck: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let url: URL?
    public let status: PersistenceLocationStatus
    public let itemCount: Int

    public init(title: String, url: URL?, status: PersistenceLocationStatus, itemCount: Int = 0) {
        self.title = title
        self.url = url?.resolvingSymlinksInPath()
        self.status = status
        self.itemCount = itemCount
        self.id = "\(title)|\(self.url?.path ?? "no-url")"
    }
}

public enum PersistenceLocationStatus: String, Codable, Sendable {
    case scanned = "Scanned"
    case missing = "Missing"
    case unreadable = "Unreadable"
    case bestEffort = "Best Effort"
}
