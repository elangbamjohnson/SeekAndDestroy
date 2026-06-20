//
//  ScanSummary.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct ScanSummary: Equatable, Sendable {
    public let scannedFileCount: Int
    public let skippedFileCount: Int
    public let scannedFiles: [URL]
    public let skippedFiles: [URL]
    public let findings: [ScanFinding]
    public let isCancelled: Bool

    public init(
        scannedFileCount: Int,
        skippedFileCount: Int,
        scannedFiles: [URL] = [],
        skippedFiles: [URL] = [],
        findings: [ScanFinding],
        isCancelled: Bool = false
    ) {
        self.scannedFileCount = scannedFileCount
        self.skippedFileCount = skippedFileCount
        self.scannedFiles = scannedFiles.map { $0.resolvingSymlinksInPath() }
        self.skippedFiles = skippedFiles.map { $0.resolvingSymlinksInPath() }
        self.findings = findings
        self.isCancelled = isCancelled
    }
}
