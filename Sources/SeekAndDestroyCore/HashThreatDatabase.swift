//
//  HashThreatDatabase.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct HashThreatDatabase: Sendable {
    private let threatsBySHA256: [String: HashThreat]

    public init(threats: [HashThreat]) {
        self.threatsBySHA256 = Dictionary(
            threats.map { ($0.sha256.lowercased(), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    public subscript(sha256 hash: String) -> HashThreat? {
        threatsBySHA256[hash.lowercased()]
    }

    public static func loadBundled() throws -> HashThreatDatabase {
        guard let url = Bundle.module.url(
            forResource: "malicious_hashes",
            withExtension: "txt"
        ) else {
            throw HashThreatDatabaseError.missingBundledHashList
        }

        return try load(from: url)
    }

    public static func load(from url: URL) throws -> HashThreatDatabase {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let threats = contents
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }

        return HashThreatDatabase(threats: threats)
    }

    private static func parseLine(_ line: String) -> HashThreat? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
            return nil
        }

        let parts = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard parts.count == 2 else {
            return nil
        }

        let hash = String(parts[0]).lowercased()
        guard isValidSHA256(hash) else {
            return nil
        }

        return HashThreat(sha256: hash, name: String(parts[1]))
    }

    private static func isValidSHA256(_ hash: String) -> Bool {
        hash.count == 64 && hash.allSatisfy { character in
            character.isNumber || ("a"..."f").contains(character)
        }
    }
}

public enum HashThreatDatabaseError: Error, Equatable {
    case missingBundledHashList
}
