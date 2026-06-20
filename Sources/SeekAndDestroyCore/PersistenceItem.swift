//
//  PersistenceItem.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct PersistenceItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: PersistenceItemKind
    public let label: String
    public let sourceURL: URL?
    public let executablePath: String?
    public let arguments: [String]
    public let contentSHA256: String?
    public let executableSHA256: String?
    public let riskFlags: [PersistenceRiskFlag]

    public init(
        kind: PersistenceItemKind,
        label: String,
        sourceURL: URL?,
        executablePath: String?,
        arguments: [String] = [],
        contentSHA256: String?,
        executableSHA256: String?,
        riskFlags: [PersistenceRiskFlag] = []
    ) {
        self.kind = kind
        self.label = label
        self.sourceURL = sourceURL?.resolvingSymlinksInPath()
        self.executablePath = executablePath
        self.arguments = arguments
        self.contentSHA256 = contentSHA256
        self.executableSHA256 = executableSHA256
        self.riskFlags = riskFlags

        let sourcePath = self.sourceURL?.path ?? "no-source"
        self.id = "\(kind.rawValue)|\(sourcePath)|\(label)"
    }
}

public enum PersistenceItemKind: String, Codable, CaseIterable, Sendable {
    case launchAgent = "LaunchAgent"
    case launchDaemon = "LaunchDaemon"
    case cron = "Cron"
    case periodicScript = "PeriodicScript"
    case configurationProfile = "ConfigurationProfile"
    case loginItem = "LoginItem"
}

public enum PersistenceRiskFlag: String, Codable, CaseIterable, Sendable {
    case runsFromDownloadsOrDesktop
    case runsFromTemporaryDirectory
    case appleLabelOutsideSystemLocation
    case missingExecutable
    case rootDaemonOutsideSystemLocation
    case unsignedExecutableCheckPending

    public var title: String {
        switch self {
        case .runsFromDownloadsOrDesktop:
            return "Runs from Downloads/Desktop"
        case .runsFromTemporaryDirectory:
            return "Runs from temporary directory"
        case .appleLabelOutsideSystemLocation:
            return "Apple-style label outside system path"
        case .missingExecutable:
            return "Executable missing"
        case .rootDaemonOutsideSystemLocation:
            return "Daemon outside system path"
        case .unsignedExecutableCheckPending:
            return "Code-signing check pending"
        }
    }
}
