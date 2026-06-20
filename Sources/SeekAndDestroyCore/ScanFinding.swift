//
//  ScanFinding.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct ScanFinding: Equatable, Sendable {
    public let fileURL: URL
    public let sha256: String
    public let kind: ScanFindingKind

    public init(fileURL: URL, sha256: String, kind: ScanFindingKind) {
        self.fileURL = fileURL.resolvingSymlinksInPath()
        self.sha256 = sha256
        self.kind = kind
    }
}

public enum ScanFindingKind: Equatable, Sendable {
    case maliciousHash(HashThreat)
}
