//
//  CodeSignatureAssessment.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct CodeSignatureAssessment: Codable, Equatable, Sendable {
    public let status: CodeSignatureStatus
    public let signingIdentifier: String?
    public let teamIdentifier: String?
    public let authorityNames: [String]
    public let isAppleSigned: Bool
    public let isAdHocSigned: Bool
    public let hasHardenedRuntime: Bool
    public let validationErrorCode: Int32?
    public let validationErrorDescription: String?

    public init(
        status: CodeSignatureStatus,
        signingIdentifier: String? = nil,
        teamIdentifier: String? = nil,
        authorityNames: [String] = [],
        isAppleSigned: Bool = false,
        isAdHocSigned: Bool = false,
        hasHardenedRuntime: Bool = false,
        validationErrorCode: Int32? = nil,
        validationErrorDescription: String? = nil
    ) {
        self.status = status
        self.signingIdentifier = signingIdentifier
        self.teamIdentifier = teamIdentifier
        self.authorityNames = authorityNames
        self.isAppleSigned = isAppleSigned
        self.isAdHocSigned = isAdHocSigned
        self.hasHardenedRuntime = hasHardenedRuntime
        self.validationErrorCode = validationErrorCode
        self.validationErrorDescription = validationErrorDescription
    }
}

public enum CodeSignatureStatus: String, Codable, Sendable {
    case valid = "Valid"
    case unsigned = "Unsigned"
    case adHoc = "Ad Hoc"
    case invalid = "Invalid"
    case missingExecutable = "Missing Executable"
    case inspectionFailed = "Inspection Failed"
}

public protocol CodeSignatureInspecting {
    func inspectCodeSignature(at url: URL) -> CodeSignatureAssessment
}
