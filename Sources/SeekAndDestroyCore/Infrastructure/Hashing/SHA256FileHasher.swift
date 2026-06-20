//
//  SHA256FileHasher.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import CryptoKit
import Foundation

public protocol FileHashing: Sendable {
    func sha256(forFileAt url: URL) throws -> String
}

public struct SHA256FileHasher: FileHashing {
    private let chunkSize: Int

    public init(chunkSize: Int = 1_048_576) {
        self.chunkSize = chunkSize
    }

    public func sha256(forFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()

        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            guard !chunk.isEmpty else {
                break
            }

            hasher.update(data: chunk)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
