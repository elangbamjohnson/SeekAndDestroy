//
//  HashThreat.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct HashThreat: Equatable, Sendable {
    public let sha256: String
    public let name: String

    public init(sha256: String, name: String) {
        self.sha256 = sha256.lowercased()
        self.name = name
    }
}
