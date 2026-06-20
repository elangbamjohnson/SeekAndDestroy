//
//  HashThreatDatabaseTests.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation
import Testing
@testable import SeekAndDestroyCore

@Suite
struct HashThreatDatabaseTests {
    @Test
    func loadsBundledHashList() throws {
        let database = try HashThreatDatabase.loadBundled()

        #expect(database[sha256: "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f"] == HashThreat(
            sha256: "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f",
            name: "EICAR-Test-File"
        ))
    }

    @Test
    func parsesHashListIgnoringCommentsAndBlankLines() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let listURL = temporaryDirectory.appendingPathComponent("hashes.txt")
        try """
        # comment

        0000000000000000000000000000000000000000000000000000000000abc123 Sample.Threat
        0000000000000000000000000000000000000000000000000000000000def456 Other.Threat
        malformed
        """.write(to: listURL, atomically: true, encoding: .utf8)

        let database = try HashThreatDatabase.load(from: listURL)

        #expect(database[sha256: "0000000000000000000000000000000000000000000000000000000000abc123"] == HashThreat(
            sha256: "0000000000000000000000000000000000000000000000000000000000abc123",
            name: "Sample.Threat"
        ))
        #expect(database[sha256: "0000000000000000000000000000000000000000000000000000000000def456"] == HashThreat(
            sha256: "0000000000000000000000000000000000000000000000000000000000def456",
            name: "Other.Threat"
        ))
        #expect(database[sha256: "malformed"] == nil)
    }
}
