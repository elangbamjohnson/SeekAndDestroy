//
//  SecurityFrameworkCodeSignatureInspector.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation
import Security

public struct SecurityFrameworkCodeSignatureInspector: CodeSignatureInspecting {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func inspectCodeSignature(at url: URL) -> CodeSignatureAssessment {
        let resolvedURL = url.resolvingSymlinksInPath()

        guard fileManager.fileExists(atPath: resolvedURL.path) else {
            return CodeSignatureAssessment(
                status: .missingExecutable,
                validationErrorDescription: "Executable does not exist"
            )
        }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(resolvedURL as CFURL, SecCSFlags(), &staticCode)

        guard createStatus == errSecSuccess, let staticCode else {
            return CodeSignatureAssessment(
                status: status(for: createStatus),
                validationErrorCode: createStatus,
                validationErrorDescription: description(for: createStatus)
            )
        }

        let validationStatus = SecStaticCodeCheckValidity(staticCode, SecCSFlags(), nil)

        var information: CFDictionary?
        let copyStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        )

        guard copyStatus == errSecSuccess, let dictionary = information as? [String: Any] else {
            let status = validationStatus == errSecCSUnsigned || copyStatus == errSecCSUnsigned
                ? CodeSignatureStatus.unsigned
                : status(for: validationStatus == errSecSuccess ? copyStatus : validationStatus)

            let errorCode = validationStatus == errSecSuccess ? copyStatus : validationStatus
            return CodeSignatureAssessment(
                status: status,
                validationErrorCode: errorCode,
                validationErrorDescription: description(for: errorCode)
            )
        }

        let signatureFlags = codeSignatureFlags(from: dictionary)
        let isAdHoc = signatureFlags.contains(.adHoc)
        let hasHardenedRuntime = signatureFlags.contains(.hardenedRuntime)
        let authorities = authorityNames(from: dictionary)
        let signingIdentifier = dictionary[kSecCodeInfoIdentifier as String] as? String
        let teamIdentifier = dictionary[kSecCodeInfoTeamIdentifier as String] as? String
        let isAppleSigned = authorities.contains { authority in
            authority.localizedCaseInsensitiveContains("Apple")
        }

        return CodeSignatureAssessment(
            status: status(for: validationStatus, isAdHoc: isAdHoc),
            signingIdentifier: signingIdentifier,
            teamIdentifier: teamIdentifier,
            authorityNames: authorities,
            isAppleSigned: isAppleSigned,
            isAdHocSigned: isAdHoc,
            hasHardenedRuntime: hasHardenedRuntime,
            validationErrorCode: validationStatus == errSecSuccess ? nil : validationStatus,
            validationErrorDescription: validationStatus == errSecSuccess ? nil : description(for: validationStatus)
        )
    }

    private func status(for osStatus: OSStatus, isAdHoc: Bool = false) -> CodeSignatureStatus {
        if osStatus == errSecSuccess {
            return isAdHoc ? .adHoc : .valid
        }

        if osStatus == errSecCSUnsigned {
            return .unsigned
        }

        return .invalid
    }

    private func codeSignatureFlags(from dictionary: [String: Any]) -> CodeSignatureFlags {
        if let number = dictionary[kSecCodeInfoFlags as String] as? NSNumber {
            return CodeSignatureFlags(rawValue: number.uint32Value)
        }

        return []
    }

    private func authorityNames(from dictionary: [String: Any]) -> [String] {
        guard let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate] else {
            return []
        }

        return certificates.compactMap { certificate in
            SecCertificateCopySubjectSummary(certificate) as String?
        }
    }

    private func description(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }

        return "OSStatus \(status)"
    }
}

private struct CodeSignatureFlags: OptionSet {
    let rawValue: UInt32

    static let adHoc = CodeSignatureFlags(rawValue: 0x0002)
    static let hardenedRuntime = CodeSignatureFlags(rawValue: 0x10000)
}
