//
//  main.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation
import SeekAndDestroyCore

let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
let defaultDirectories = [
    homeDirectory.appendingPathComponent("Downloads"),
    homeDirectory.appendingPathComponent("Desktop"),
    URL(fileURLWithPath: "/Applications")
]

let directories = CommandLine.arguments.dropFirst().map(URL.init(fileURLWithPath:))
let scanDirectories = directories.isEmpty ? defaultDirectories : directories

let database = try HashThreatDatabase.loadBundled()
let scanner = OnDemandScanner(threatDatabase: database)
let summary = scanner.scan(directories: scanDirectories)

print("Scanned files: \(summary.scannedFileCount)")
print("Skipped files: \(summary.skippedFileCount)")
print("Findings: \(summary.findings.count)")

for finding in summary.findings {
    switch finding.kind {
    case .maliciousHash(let threat):
        print("[malicious-hash] \(threat.name) \(finding.sha256) \(finding.fileURL.path)")
    }
}
