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
    public let codeSignature: CodeSignatureAssessment?
    public let riskFlags: [PersistenceRiskFlag]
    public let launchdDetails: LaunchdDetails?
    public let configurationProfileDetails: ConfigurationProfileDetails?
    public let loginItemDetails: LoginItemDetails?

    public init(
        kind: PersistenceItemKind,
        label: String,
        sourceURL: URL?,
        executablePath: String?,
        arguments: [String] = [],
        contentSHA256: String?,
        executableSHA256: String?,
        codeSignature: CodeSignatureAssessment? = nil,
        riskFlags: [PersistenceRiskFlag] = [],
        launchdDetails: LaunchdDetails? = nil,
        configurationProfileDetails: ConfigurationProfileDetails? = nil,
        loginItemDetails: LoginItemDetails? = nil
    ) {
        self.kind = kind
        self.label = label
        self.sourceURL = sourceURL?.resolvingSymlinksInPath()
        self.executablePath = executablePath
        self.arguments = arguments
        self.contentSHA256 = contentSHA256
        self.executableSHA256 = executableSHA256
        self.codeSignature = codeSignature
        self.riskFlags = riskFlags
        self.launchdDetails = launchdDetails
        self.configurationProfileDetails = configurationProfileDetails
        self.loginItemDetails = loginItemDetails

        let sourcePath = self.sourceURL?.path ?? "no-source"
        self.id = "\(kind.rawValue)|\(sourcePath)|\(label)"
    }
}

public struct LaunchdDetails: Codable, Equatable, Sendable {
    public let runAtLoad: Bool?
    public let keepAlive: LaunchdKeepAliveDetails?
    public let startInterval: Int?
    public let startCalendarIntervals: [String]
    public let watchPaths: [String]
    public let queueDirectories: [String]
    public let machServices: [String]
    public let sockets: [String]
    public let standardOutPath: String?
    public let standardErrorPath: String?
    public let workingDirectory: String?
    public let environmentVariables: [String: String]

    public init(
        runAtLoad: Bool?,
        keepAlive: LaunchdKeepAliveDetails?,
        startInterval: Int?,
        startCalendarIntervals: [String] = [],
        watchPaths: [String] = [],
        queueDirectories: [String] = [],
        machServices: [String] = [],
        sockets: [String] = [],
        standardOutPath: String? = nil,
        standardErrorPath: String? = nil,
        workingDirectory: String? = nil,
        environmentVariables: [String: String] = [:]
    ) {
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
        self.startInterval = startInterval
        self.startCalendarIntervals = startCalendarIntervals
        self.watchPaths = watchPaths
        self.queueDirectories = queueDirectories
        self.machServices = machServices
        self.sockets = sockets
        self.standardOutPath = standardOutPath
        self.standardErrorPath = standardErrorPath
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
    }

    public var hasDisplayedValues: Bool {
        runAtLoad != nil
            || keepAlive != nil
            || startInterval != nil
            || !startCalendarIntervals.isEmpty
            || !watchPaths.isEmpty
            || !queueDirectories.isEmpty
            || !machServices.isEmpty
            || !sockets.isEmpty
            || standardOutPath != nil
            || standardErrorPath != nil
            || workingDirectory != nil
            || !environmentVariables.isEmpty
    }
}

public struct LaunchdKeepAliveDetails: Codable, Equatable, Sendable {
    public let enabled: Bool?
    public let successfulExit: Bool?
    public let crashed: Bool?
    public let networkState: Bool?
    public let pathStateKeys: [String]
    public let otherKeys: [String]

    public init(
        enabled: Bool? = nil,
        successfulExit: Bool? = nil,
        crashed: Bool? = nil,
        networkState: Bool? = nil,
        pathStateKeys: [String] = [],
        otherKeys: [String] = []
    ) {
        self.enabled = enabled
        self.successfulExit = successfulExit
        self.crashed = crashed
        self.networkState = networkState
        self.pathStateKeys = pathStateKeys
        self.otherKeys = otherKeys
    }

    public var displaySummary: String {
        var parts: [String] = []

        if let enabled {
            parts.append(enabled ? "enabled" : "disabled")
        }

        if let successfulExit {
            parts.append("SuccessfulExit=\(successfulExit)")
        }

        if let crashed {
            parts.append("Crashed=\(crashed)")
        }

        if let networkState {
            parts.append("NetworkState=\(networkState)")
        }

        if !pathStateKeys.isEmpty {
            parts.append("PathState: \(pathStateKeys.joined(separator: ", "))")
        }

        if !otherKeys.isEmpty {
            parts.append("Other: \(otherKeys.joined(separator: ", "))")
        }

        return parts.isEmpty ? "configured" : parts.joined(separator: "; ")
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
    case unsignedExecutable
    case adHocSignedExecutable
    case invalidCodeSignature
    case nonRemovableConfigurationProfile
    case configurationProfileInstallsCertificate
    case configurationProfileControlsNetwork

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
        case .unsignedExecutable:
            return "Unsigned executable"
        case .adHocSignedExecutable:
            return "Ad-hoc signed executable"
        case .invalidCodeSignature:
            return "Invalid code signature"
        case .nonRemovableConfigurationProfile:
            return "Non-removable configuration profile"
        case .configurationProfileInstallsCertificate:
            return "Profile installs certificate material"
        case .configurationProfileControlsNetwork:
            return "Profile controls network settings"
        }
    }
}
