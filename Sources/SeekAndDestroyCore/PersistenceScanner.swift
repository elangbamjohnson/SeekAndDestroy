//
//  PersistenceScanner.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct PersistenceScanConfiguration: Sendable {
    public let launchAgentDirectories: [URL]
    public let launchDaemonDirectories: [URL]
    public let cronFiles: [URL]
    public let cronDirectories: [URL]
    public let periodicDirectories: [URL]
    public let profileLocations: [URL]
    public let loginItemLocations: [URL]

    public init(
        launchAgentDirectories: [URL],
        launchDaemonDirectories: [URL],
        cronFiles: [URL],
        cronDirectories: [URL],
        periodicDirectories: [URL],
        profileLocations: [URL],
        loginItemLocations: [URL]
    ) {
        self.launchAgentDirectories = launchAgentDirectories
        self.launchDaemonDirectories = launchDaemonDirectories
        self.cronFiles = cronFiles
        self.cronDirectories = cronDirectories
        self.periodicDirectories = periodicDirectories
        self.profileLocations = profileLocations
        self.loginItemLocations = loginItemLocations
    }

    public static func liveSystem(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> PersistenceScanConfiguration {
        PersistenceScanConfiguration(
            launchAgentDirectories: [
                homeDirectory.appendingPathComponent("Library/LaunchAgents"),
                URL(fileURLWithPath: "/Library/LaunchAgents"),
                URL(fileURLWithPath: "/System/Library/LaunchAgents")
            ],
            launchDaemonDirectories: [
                URL(fileURLWithPath: "/Library/LaunchDaemons"),
                URL(fileURLWithPath: "/System/Library/LaunchDaemons")
            ],
            cronFiles: [
                URL(fileURLWithPath: "/etc/crontab")
            ],
            cronDirectories: [
                URL(fileURLWithPath: "/usr/lib/cron/tabs"),
                URL(fileURLWithPath: "/var/at/tabs")
            ],
            periodicDirectories: [
                URL(fileURLWithPath: "/etc/periodic/daily"),
                URL(fileURLWithPath: "/etc/periodic/weekly"),
                URL(fileURLWithPath: "/etc/periodic/monthly"),
                URL(fileURLWithPath: "/usr/local/etc/periodic/daily"),
                URL(fileURLWithPath: "/usr/local/etc/periodic/weekly"),
                URL(fileURLWithPath: "/usr/local/etc/periodic/monthly")
            ],
            profileLocations: [
                URL(fileURLWithPath: "/Library/Managed Preferences"),
                URL(fileURLWithPath: "/var/db/ConfigurationProfiles")
            ],
            loginItemLocations: [
                URL(fileURLWithPath: "/var/db/com.apple.backgroundtaskmanagement")
            ]
        )
    }
}

public struct PersistenceScanner {
    private let fileManager: FileManager
    private let hasher: any FileHashing
    private let configuration: PersistenceScanConfiguration

    public init(
        fileManager: FileManager = .default,
        hasher: any FileHashing = SHA256FileHasher(),
        configuration: PersistenceScanConfiguration = .liveSystem()
    ) {
        self.fileManager = fileManager
        self.hasher = hasher
        self.configuration = configuration
    }

    public func scan(
        baseline: PersistenceBaseline? = nil,
        shouldCancel: @escaping @Sendable () -> Bool = { false }
    ) -> PersistenceScanSummary {
        var items: [PersistenceItem] = []
        var checks: [PersistenceLocationCheck] = []
        var isCancelled = false

        scanLaunchd(kind: .launchAgent, directories: configuration.launchAgentDirectories, items: &items, checks: &checks, shouldCancel: shouldCancel, isCancelled: &isCancelled)
        scanLaunchd(kind: .launchDaemon, directories: configuration.launchDaemonDirectories, items: &items, checks: &checks, shouldCancel: shouldCancel, isCancelled: &isCancelled)
        scanCronFiles(items: &items, checks: &checks, shouldCancel: shouldCancel, isCancelled: &isCancelled)
        scanPeriodicScripts(items: &items, checks: &checks, shouldCancel: shouldCancel, isCancelled: &isCancelled)
        recordBestEffortLocations(title: "Configuration Profiles", locations: configuration.profileLocations, checks: &checks, shouldCancel: shouldCancel, isCancelled: &isCancelled)
        recordBestEffortLocations(title: "Login Items", locations: configuration.loginItemLocations, checks: &checks, shouldCancel: shouldCancel, isCancelled: &isCancelled)

        return PersistenceScanSummary(
            assessedItems: assess(items: items, baseline: baseline),
            checkedLocations: checks,
            baselineGeneratedAt: baseline?.generatedAt,
            isCancelled: isCancelled
        )
    }

    public func createBaseline(shouldCancel: @escaping @Sendable () -> Bool = { false }) -> PersistenceBaseline {
        let summary = scan(baseline: nil, shouldCancel: shouldCancel)
        return PersistenceBaseline(persistenceItems: summary.assessedItems.map(\.item))
    }

    private func scanLaunchd(
        kind: PersistenceItemKind,
        directories: [URL],
        items: inout [PersistenceItem],
        checks: inout [PersistenceLocationCheck],
        shouldCancel: @escaping @Sendable () -> Bool,
        isCancelled: inout Bool
    ) {
        for directory in directories {
            guard !isCancelled, !shouldCancel() else {
                isCancelled = true
                break
            }

            let beforeCount = items.count
            let status = enumerateRegularFiles(in: directory, allowedExtension: "plist", shouldCancel: shouldCancel, isCancelled: &isCancelled) { plistURL in
                guard let item = launchdItem(kind: kind, plistURL: plistURL) else {
                    return
                }

                items.append(item)
            }

            checks.append(PersistenceLocationCheck(
                title: kind.rawValue,
                url: directory,
                status: status,
                itemCount: items.count - beforeCount
            ))
        }
    }

    private func scanCronFiles(
        items: inout [PersistenceItem],
        checks: inout [PersistenceLocationCheck],
        shouldCancel: @escaping @Sendable () -> Bool,
        isCancelled: inout Bool
    ) {
        for fileURL in configuration.cronFiles {
            guard !isCancelled, !shouldCancel() else {
                isCancelled = true
                break
            }

            let beforeCount = items.count
            let status = scanCronFile(fileURL, items: &items)
            checks.append(PersistenceLocationCheck(
                title: "Cron",
                url: fileURL,
                status: status,
                itemCount: items.count - beforeCount
            ))
        }

        for directory in configuration.cronDirectories {
            guard !isCancelled, !shouldCancel() else {
                isCancelled = true
                break
            }

            let beforeCount = items.count
            let status = enumerateRegularFiles(in: directory, allowedExtension: nil, shouldCancel: shouldCancel, isCancelled: &isCancelled) { fileURL in
                _ = scanCronFile(fileURL, items: &items)
            }
            checks.append(PersistenceLocationCheck(
                title: "Cron",
                url: directory,
                status: status,
                itemCount: items.count - beforeCount
            ))
        }
    }

    private func scanPeriodicScripts(
        items: inout [PersistenceItem],
        checks: inout [PersistenceLocationCheck],
        shouldCancel: @escaping @Sendable () -> Bool,
        isCancelled: inout Bool
    ) {
        for directory in configuration.periodicDirectories {
            guard !isCancelled, !shouldCancel() else {
                isCancelled = true
                break
            }

            let beforeCount = items.count
            let status = enumerateRegularFiles(in: directory, allowedExtension: nil, shouldCancel: shouldCancel, isCancelled: &isCancelled) { scriptURL in
                let sourceHash = try? hasher.sha256(forFileAt: scriptURL)
                items.append(PersistenceItem(
                    kind: .periodicScript,
                    label: scriptURL.lastPathComponent,
                    sourceURL: scriptURL,
                    executablePath: scriptURL.path,
                    contentSHA256: sourceHash,
                    executableSHA256: sourceHash,
                    riskFlags: riskFlags(kind: .periodicScript, label: scriptURL.lastPathComponent, sourceURL: scriptURL, executablePath: scriptURL.path)
                ))
            }
            checks.append(PersistenceLocationCheck(
                title: "Periodic Scripts",
                url: directory,
                status: status,
                itemCount: items.count - beforeCount
            ))
        }
    }

    private func recordBestEffortLocations(
        title: String,
        locations: [URL],
        checks: inout [PersistenceLocationCheck],
        shouldCancel: @escaping @Sendable () -> Bool,
        isCancelled: inout Bool
    ) {
        for location in locations {
            guard !isCancelled, !shouldCancel() else {
                isCancelled = true
                break
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: location.path, isDirectory: &isDirectory) else {
                checks.append(PersistenceLocationCheck(title: title, url: location, status: .missing))
                continue
            }

            checks.append(PersistenceLocationCheck(
                title: title,
                url: location,
                status: isDirectory.boolValue ? .bestEffort : .scanned
            ))
        }
    }

    private func launchdItem(kind: PersistenceItemKind, plistURL: URL) -> PersistenceItem? {
        guard
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return nil
        }

        let label = dictionary["Label"] as? String ?? plistURL.deletingPathExtension().lastPathComponent
        let arguments = dictionary["ProgramArguments"] as? [String] ?? []
        let executablePath = dictionary["Program"] as? String ?? arguments.first
        let sourceHash = try? hasher.sha256(forFileAt: plistURL)
        let executableHash = executablePath.flatMap { hashExecutable(atPath: $0) }

        return PersistenceItem(
            kind: kind,
            label: label,
            sourceURL: plistURL,
            executablePath: executablePath,
            arguments: arguments,
            contentSHA256: sourceHash,
            executableSHA256: executableHash,
            riskFlags: riskFlags(kind: kind, label: label, sourceURL: plistURL, executablePath: executablePath)
        )
    }

    private func scanCronFile(_ fileURL: URL, items: inout [PersistenceItem]) -> PersistenceLocationStatus {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .missing
        }

        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return .unreadable
        }

        let sourceHash = try? hasher.sha256(forFileAt: fileURL)
        for (index, line) in contents.split(whereSeparator: \.isNewline).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }

            let label = "\(fileURL.lastPathComponent):\(index + 1)"
            items.append(PersistenceItem(
                kind: .cron,
                label: label,
                sourceURL: fileURL,
                executablePath: nil,
                arguments: [trimmed],
                contentSHA256: sourceHash,
                executableSHA256: nil,
                riskFlags: []
            ))
        }

        return .scanned
    }

    private func enumerateRegularFiles(
        in directory: URL,
        allowedExtension: String?,
        shouldCancel: @escaping @Sendable () -> Bool,
        isCancelled: inout Bool,
        body: (URL) -> Void
    ) -> PersistenceLocationStatus {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
            return .missing
        }

        guard isDirectory.boolValue else {
            return .unreadable
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return .unreadable
        }

        for case let fileURL as URL in enumerator {
            guard !shouldCancel() else {
                isCancelled = true
                break
            }

            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            if let allowedExtension, fileURL.pathExtension != allowedExtension {
                continue
            }

            body(fileURL)
        }

        return .scanned
    }

    private func hashExecutable(atPath path: String) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard fileManager.fileExists(atPath: expandedPath) else {
            return nil
        }

        return try? hasher.sha256(forFileAt: URL(fileURLWithPath: expandedPath))
    }

    private func assess(items: [PersistenceItem], baseline: PersistenceBaseline?) -> [PersistenceAssessment] {
        guard let baseline else {
            return items.map { PersistenceAssessment(item: $0, baselineStatus: .noBaseline) }
        }

        let baselineItems = baseline.itemsByID

        return items.map { item in
            guard let baselineItem = baselineItems[item.id] else {
                return PersistenceAssessment(item: item, baselineStatus: .new)
            }

            let changed = baselineItem.contentSHA256 != item.contentSHA256
                || baselineItem.executableSHA256 != item.executableSHA256
                || baselineItem.executablePath != item.executablePath

            return PersistenceAssessment(item: item, baselineStatus: changed ? .changed : .known)
        }
    }

    private func riskFlags(
        kind: PersistenceItemKind,
        label: String,
        sourceURL: URL,
        executablePath: String?
    ) -> [PersistenceRiskFlag] {
        var flags: [PersistenceRiskFlag] = []
        let sourcePath = sourceURL.path
        let executable = executablePath?.lowercased() ?? ""

        if executable.hasPrefix("/tmp/") || executable.hasPrefix("/private/tmp/") || executable.hasPrefix("/var/tmp/") {
            flags.append(.runsFromTemporaryDirectory)
        }

        if executable.contains("/downloads/") || executable.contains("/desktop/") {
            flags.append(.runsFromDownloadsOrDesktop)
        }

        if label.hasPrefix("com.apple."), !sourcePath.hasPrefix("/System/Library/") {
            flags.append(.appleLabelOutsideSystemLocation)
        }

        if kind == .launchDaemon, !sourcePath.hasPrefix("/System/Library/") {
            flags.append(.rootDaemonOutsideSystemLocation)
        }

        if let executablePath, hashExecutable(atPath: executablePath) == nil {
            flags.append(.missingExecutable)
        }

        if executablePath != nil {
            flags.append(.unsignedExecutableCheckPending)
        }

        return Array(Set(flags)).sorted { $0.rawValue < $1.rawValue }
    }
}
