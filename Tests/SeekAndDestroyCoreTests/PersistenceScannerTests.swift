//
//  PersistenceScannerTests.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation
import Testing
@testable import SeekAndDestroyCore

@Suite
struct PersistenceScannerTests {
    @Test
    func scansLaunchAgentPlists() throws {
        let fixture = try PersistenceFixture()
        defer {
            fixture.cleanUp()
        }

        let executableURL = fixture.root.appendingPathComponent("helper.sh")
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        _ = try fixture.writeLaunchAgent(
            label: "com.example.helper",
            executablePath: executableURL.path
        )

        let scanner = PersistenceScanner(configuration: fixture.configuration)
        let summary = scanner.scan()

        #expect(summary.assessedItems.count == 1)
        #expect(summary.assessedItems[0].item.kind == .launchAgent)
        #expect(summary.assessedItems[0].item.label == "com.example.helper")
        #expect(summary.assessedItems[0].baselineStatus == .noBaseline)
    }

    @Test
    func comparesCurrentItemsAgainstBaseline() throws {
        let fixture = try PersistenceFixture()
        defer {
            fixture.cleanUp()
        }

        let executableURL = fixture.root.appendingPathComponent("helper.sh")
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        let plistURL = try fixture.writeLaunchAgent(
            label: "com.example.helper",
            executablePath: executableURL.path
        )

        let scanner = PersistenceScanner(configuration: fixture.configuration)
        let baseline = scanner.createBaseline()

        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.example.helper</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(executableURL.path)</string>
            <string>--changed</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        """.write(to: plistURL, atomically: true, encoding: .utf8)

        let summary = scanner.scan(baseline: baseline)

        #expect(summary.changedItemCount == 1)
        #expect(summary.assessedItems[0].baselineStatus == .changed)
    }

    @Test
    func stopsPersistenceScanWhenCancelled() throws {
        let fixture = try PersistenceFixture()
        defer {
            fixture.cleanUp()
        }

        _ = try fixture.writeLaunchAgent(
            label: "com.example.helper",
            executablePath: "/tmp/helper.sh"
        )

        let scanner = PersistenceScanner(configuration: fixture.configuration)
        let summary = scanner.scan(shouldCancel: { true })

        #expect(summary.isCancelled)
        #expect(summary.assessedItems.isEmpty)
    }
}

private struct PersistenceFixture {
    let root: URL
    let launchAgents: URL
    let configuration: PersistenceScanConfiguration

    init() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        launchAgents = root.appendingPathComponent("LaunchAgents", isDirectory: true)
        try FileManager.default.createDirectory(at: launchAgents, withIntermediateDirectories: true)

        configuration = PersistenceScanConfiguration(
            launchAgentDirectories: [launchAgents],
            launchDaemonDirectories: [],
            cronFiles: [],
            cronDirectories: [],
            periodicDirectories: [],
            profileLocations: [],
            loginItemLocations: []
        )
    }

    func writeLaunchAgent(label: String, executablePath: String) throws -> URL {
        let plistURL = launchAgents.appendingPathComponent("\(label).plist")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(label)</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(executablePath)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        """.write(to: plistURL, atomically: true, encoding: .utf8)

        return plistURL
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
