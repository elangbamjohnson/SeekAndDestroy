//
//  OnDemandScannerTests.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import CryptoKit
import Foundation
import Testing
@testable import SeekAndDestroyCore

@Suite
struct OnDemandScannerTests {
    @Test
    func reportsFilesWhoseSHA256ExistsInThreatDatabase() throws {
        let fixture = try TemporaryScanFixture()
        defer {
            fixture.cleanUp()
        }

        let maliciousData = Data("malicious bytes".utf8)
        let maliciousHash = SHA256.hash(data: maliciousData)
            .map { String(format: "%02x", $0) }
            .joined()

        let maliciousFileURL = fixture.root.appendingPathComponent("payload.bin")
        try maliciousData.write(to: maliciousFileURL)
        try Data("ordinary bytes".utf8).write(to: fixture.root.appendingPathComponent("notes.txt"))

        let database = HashThreatDatabase(
            threats: [
                HashThreat(sha256: maliciousHash, name: "UnitTest.Payload")
            ]
        )
        let scanner = OnDemandScanner(threatDatabase: database)

        let summary = scanner.scan(directories: [fixture.root])

        #expect(summary.scannedFileCount == 2)
        #expect(summary.findings == [
            ScanFinding(
                fileURL: maliciousFileURL,
                sha256: maliciousHash,
                kind: .maliciousHash(HashThreat(sha256: maliciousHash, name: "UnitTest.Payload"))
            )
        ])
    }

    @Test
    func emitsProgressEventsWhileScanning() throws {
        let fixture = try TemporaryScanFixture()
        defer {
            fixture.cleanUp()
        }

        let fileURL = fixture.root.appendingPathComponent("sample.txt")
        try Data("sample".utf8).write(to: fileURL)

        let recorder = ScanEventRecorder()
        let scanner = OnDemandScanner(threatDatabase: HashThreatDatabase(threats: []))

        let summary = scanner.scan(directories: [fixture.root]) { event in
            recorder.record(event)
        }

        #expect(summary.scannedFileCount == 1)
        #expect(summary.scannedFiles == [fileURL.resolvingSymlinksInPath()])
        #expect(recorder.events == [.scannedFile(fileURL.resolvingSymlinksInPath())])
    }

    @Test
    func stopsScanningWhenCancelled() throws {
        let fixture = try TemporaryScanFixture()
        defer {
            fixture.cleanUp()
        }

        try Data("one".utf8).write(to: fixture.root.appendingPathComponent("one.txt"))

        let scanner = OnDemandScanner(threatDatabase: HashThreatDatabase(threats: []))
        let summary = scanner.scan(directories: [fixture.root], shouldCancel: { true })

        #expect(summary.isCancelled)
        #expect(summary.scannedFileCount == 0)
    }
}

private struct TemporaryScanFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}

private final class ScanEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var events: [ScanProgressEvent] = []

    func record(_ event: ScanProgressEvent) {
        lock.withLock {
            events.append(event)
        }
    }
}
