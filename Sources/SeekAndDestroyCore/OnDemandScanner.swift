//
//  OnDemandScanner.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct OnDemandScanner {
    private let fileManager: FileManager
    private let hasher: any FileHashing
    private let threatDatabase: HashThreatDatabase

    public init(
        fileManager: FileManager = .default,
        hasher: any FileHashing = SHA256FileHasher(),
        threatDatabase: HashThreatDatabase
    ) {
        self.fileManager = fileManager
        self.hasher = hasher
        self.threatDatabase = threatDatabase
    }

    public func scan(
        directories: [URL],
        progressHandler: (@Sendable (ScanProgressEvent) -> Void)? = nil,
        shouldCancel: @escaping @Sendable () -> Bool = { false }
    ) -> ScanSummary {
        var scannedFileCount = 0
        var skippedFileCount = 0
        var scannedFiles: [URL] = []
        var skippedFiles: [URL] = []
        var findings: [ScanFinding] = []
        var isCancelled = false

        for directory in directories {
            guard !shouldCancel() else {
                isCancelled = true
                break
            }

            let result = scan(
                directory: directory,
                progressHandler: progressHandler,
                shouldCancel: shouldCancel
            )
            scannedFileCount += result.scannedFileCount
            skippedFileCount += result.skippedFileCount
            scannedFiles.append(contentsOf: result.scannedFiles)
            skippedFiles.append(contentsOf: result.skippedFiles)
            findings.append(contentsOf: result.findings)

            if result.isCancelled {
                isCancelled = true
                break
            }
        }

        return ScanSummary(
            scannedFileCount: scannedFileCount,
            skippedFileCount: skippedFileCount,
            scannedFiles: scannedFiles,
            skippedFiles: skippedFiles,
            findings: findings,
            isCancelled: isCancelled
        )
    }

    private func scan(
        directory: URL,
        progressHandler: (@Sendable (ScanProgressEvent) -> Void)?,
        shouldCancel: @escaping @Sendable () -> Bool
    ) -> ScanSummary {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isReadableKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            let skippedURL = directory.resolvingSymlinksInPath()
            progressHandler?(.skippedFile(skippedURL))
            return ScanSummary(
                scannedFileCount: 0,
                skippedFileCount: 1,
                skippedFiles: [skippedURL],
                findings: []
            )
        }

        var scannedFileCount = 0
        var skippedFileCount = 0
        var scannedFiles: [URL] = []
        var skippedFiles: [URL] = []
        var findings: [ScanFinding] = []
        var isCancelled = false

        for case let fileURL as URL in enumerator {
            guard !shouldCancel() else {
                isCancelled = true
                break
            }

            do {
                let candidate = try scanCandidate(for: fileURL)

                switch candidate {
                case .ignore:
                    continue
                case .skip:
                    let skippedURL = fileURL.resolvingSymlinksInPath()
                    skippedFileCount += 1
                    skippedFiles.append(skippedURL)
                    progressHandler?(.skippedFile(skippedURL))
                    continue
                case .scan:
                    break
                }

                let hash = try hasher.sha256(forFileAt: fileURL)
                let scannedURL = fileURL.resolvingSymlinksInPath()
                scannedFileCount += 1
                scannedFiles.append(scannedURL)
                progressHandler?(.scannedFile(scannedURL))

                if let threat = threatDatabase[sha256: hash] {
                    let finding = ScanFinding(
                        fileURL: fileURL,
                        sha256: hash,
                        kind: .maliciousHash(threat)
                    )
                    findings.append(finding)
                    progressHandler?(.finding(finding))
                }
            } catch {
                let skippedURL = fileURL.resolvingSymlinksInPath()
                skippedFileCount += 1
                skippedFiles.append(skippedURL)
                progressHandler?(.skippedFile(skippedURL))
            }
        }

        return ScanSummary(
            scannedFileCount: scannedFileCount,
            skippedFileCount: skippedFileCount,
            scannedFiles: scannedFiles,
            skippedFiles: skippedFiles,
            findings: findings,
            isCancelled: isCancelled
        )
    }

    private func scanCandidate(for url: URL) throws -> FileScanCandidate {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isReadableKey])
        guard values.isRegularFile == true else {
            return .ignore
        }

        return values.isReadable == true ? .scan : .skip
    }
}

private enum FileScanCandidate {
    case scan
    case skip
    case ignore
}
