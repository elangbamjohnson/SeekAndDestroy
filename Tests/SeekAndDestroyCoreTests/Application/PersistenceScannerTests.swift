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

        let scanner = fixture.scanner()
        let summary = scanner.scan()

        #expect(summary.assessedItems.count == 1)
        #expect(summary.assessedItems[0].item.kind == .launchAgent)
        #expect(summary.assessedItems[0].item.label == "com.example.helper")
        #expect(summary.assessedItems[0].baselineStatus == .noBaseline)
        #expect(summary.assessedItems[0].item.launchdDetails?.runAtLoad == true)
    }

    @Test
    func parsesLaunchdBehaviorFields() throws {
        let fixture = try PersistenceFixture()
        defer {
            fixture.cleanUp()
        }

        let executableURL = fixture.root.appendingPathComponent("helper.sh")
        try "#!/bin/sh\n".write(to: executableURL, atomically: true, encoding: .utf8)

        _ = try fixture.writeLaunchAgentPlist(
            label: "com.example.rich",
            body: """
              <key>ProgramArguments</key>
              <array>
                <string>\(executableURL.path)</string>
              </array>
              <key>RunAtLoad</key>
              <true/>
              <key>KeepAlive</key>
              <dict>
                <key>SuccessfulExit</key>
                <false/>
                <key>Crashed</key>
                <true/>
                <key>NetworkState</key>
                <true/>
                <key>PathState</key>
                <dict>
                  <key>/tmp/trigger</key>
                  <true/>
                </dict>
              </dict>
              <key>StartInterval</key>
              <integer>300</integer>
              <key>StartCalendarInterval</key>
              <array>
                <dict>
                  <key>Hour</key>
                  <integer>2</integer>
                  <key>Minute</key>
                  <integer>30</integer>
                </dict>
              </array>
              <key>WatchPaths</key>
              <array>
                <string>/Users/example/Library/Application Support</string>
              </array>
              <key>QueueDirectories</key>
              <array>
                <string>/Users/example/Library/Caches</string>
              </array>
              <key>MachServices</key>
              <dict>
                <key>com.example.rich.service</key>
                <true/>
              </dict>
              <key>Sockets</key>
              <dict>
                <key>Listener</key>
                <dict/>
              </dict>
              <key>StandardOutPath</key>
              <string>/tmp/rich.out</string>
              <key>StandardErrorPath</key>
              <string>/tmp/rich.err</string>
              <key>WorkingDirectory</key>
              <string>/tmp</string>
              <key>EnvironmentVariables</key>
              <dict>
                <key>MODE</key>
                <string>test</string>
              </dict>
            """
        )

        let scanner = fixture.scanner()
        let item = scanner.scan().assessedItems[0].item
        let details = try #require(item.launchdDetails)

        #expect(details.runAtLoad == true)
        #expect(details.keepAlive?.successfulExit == false)
        #expect(details.keepAlive?.crashed == true)
        #expect(details.keepAlive?.networkState == true)
        #expect(details.keepAlive?.pathStateKeys == ["/tmp/trigger"])
        #expect(details.startInterval == 300)
        #expect(details.startCalendarIntervals == ["Hour=2, Minute=30"])
        #expect(details.watchPaths == ["/Users/example/Library/Application Support"])
        #expect(details.queueDirectories == ["/Users/example/Library/Caches"])
        #expect(details.machServices == ["com.example.rich.service"])
        #expect(details.sockets == ["Listener"])
        #expect(details.standardOutPath == "/tmp/rich.out")
        #expect(details.standardErrorPath == "/tmp/rich.err")
        #expect(details.workingDirectory == "/tmp")
        #expect(details.environmentVariables == ["MODE": "test"])
    }

    @Test
    func attachesCodeSignatureAssessmentToLaunchdExecutables() throws {
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

        let inspector = FakeCodeSignatureInspector(result: CodeSignatureAssessment(
            status: .adHoc,
            signingIdentifier: "com.example.helper",
            teamIdentifier: nil,
            authorityNames: [],
            isAppleSigned: false,
            isAdHocSigned: true,
            hasHardenedRuntime: false
        ))
        let scanner = PersistenceScanner(
            codeSignatureInspector: inspector,
            loginItemInventoryProvider: fixture.emptyLoginItemProvider,
            configuration: fixture.configuration
        )

        let item = scanner.scan().assessedItems[0].item

        #expect(item.codeSignature?.status == .adHoc)
        #expect(item.codeSignature?.signingIdentifier == "com.example.helper")
        #expect(item.riskFlags.contains(.adHocSignedExecutable))
        #expect(!item.riskFlags.contains(.unsignedExecutableCheckPending))
    }

    @Test
    func includesLoginItemsFromInventoryProvider() throws {
        let fixture = try PersistenceFixture()
        defer {
            fixture.cleanUp()
        }

        let executableURL = fixture.root.appendingPathComponent("LoginHelper")
        try Data("helper".utf8).write(to: executableURL)

        let loginItem = LoginItemDetails(
            displayName: "Example Login Helper",
            bundleIdentifier: "com.example.loginhelper",
            teamIdentifier: "TEAM123456",
            developerName: "Example Developer",
            itemType: "app",
            disposition: "enabled",
            bundleURL: fixture.root.appendingPathComponent("Example.app", isDirectory: true),
            executableURL: executableURL
        )
        let scanner = PersistenceScanner(
            codeSignatureInspector: FakeCodeSignatureInspector(result: CodeSignatureAssessment(
                status: .valid,
                signingIdentifier: "com.example.loginhelper",
                teamIdentifier: "TEAM123456",
                authorityNames: ["Developer ID Application: Example Developer"],
                isAppleSigned: false,
                isAdHocSigned: false,
                hasHardenedRuntime: true
            )),
            loginItemInventoryProvider: FakeLoginItemInventoryProvider(inventory: LoginItemInventory(
                items: [loginItem],
                status: .scanned
            )),
            configuration: fixture.configuration
        )

        let summary = scanner.scan()
        let item = try #require(summary.assessedItems.first { $0.item.kind == .loginItem }?.item)

        #expect(item.label == "Example Login Helper")
        #expect(item.loginItemDetails?.bundleIdentifier == "com.example.loginhelper")
        #expect(item.codeSignature?.teamIdentifier == "TEAM123456")
        #expect(item.codeSignature?.hasHardenedRuntime == true)
        #expect(summary.checkedLocations.contains { $0.title == "Login Items" && $0.status == .scanned && $0.itemCount == 1 })
    }

    @Test
    func parsesLoginItemDumpRecords() {
        let output = """
        Name: Example Login Helper
        Bundle Identifier: com.example.loginhelper
        Team Identifier: TEAM123456
        Developer Name: Example Developer
        Type: app
        Disposition: enabled
        Bundle URL: /Applications/Example.app
        Executable Path: /Applications/Example.app/Contents/MacOS/Example

        Name: Other Background Item
        Identifier: com.example.other
        URL: file:///Applications/Other.app
        """

        let items = LoginItemDumpParser.parse(output)

        #expect(items.count == 2)
        #expect(items[0].displayName == "Example Login Helper")
        #expect(items[0].bundleIdentifier == "com.example.loginhelper")
        #expect(items[0].teamIdentifier == "TEAM123456")
        #expect(items[0].bundleURL?.path == "/Applications/Example.app")
        #expect(items[0].executableURL?.path == "/Applications/Example.app/Contents/MacOS/Example")
        #expect(items[1].displayName == "Other Background Item")
        #expect(items[1].bundleIdentifier == "com.example.other")
        #expect(items[1].bundleURL?.path == "/Applications/Other.app")
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

        let scanner = fixture.scanner()
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

        let scanner = fixture.scanner()
        let summary = scanner.scan(shouldCancel: { true })

        #expect(summary.isCancelled)
        #expect(summary.assessedItems.isEmpty)
    }
}

private struct FakeCodeSignatureInspector: CodeSignatureInspecting {
    let result: CodeSignatureAssessment

    func inspectCodeSignature(at url: URL) -> CodeSignatureAssessment {
        result
    }
}

private struct FakeLoginItemInventoryProvider: LoginItemInventoryProviding {
    let inventory: LoginItemInventory

    func inventoryLoginItems() -> LoginItemInventory {
        inventory
    }
}

private struct PersistenceFixture {
    let root: URL
    let launchAgents: URL
    let configuration: PersistenceScanConfiguration
    let emptyLoginItemProvider = FakeLoginItemInventoryProvider(inventory: LoginItemInventory(
        items: [],
        status: .scanned
    ))

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
        try writeLaunchAgentPlist(
            label: label,
            body: """
              <key>ProgramArguments</key>
              <array>
                <string>\(executablePath)</string>
              </array>
              <key>RunAtLoad</key>
              <true/>
            """
        )
    }

    func writeLaunchAgentPlist(label: String, body: String) throws -> URL {
        let plistURL = launchAgents.appendingPathComponent("\(label).plist")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(label)</string>
        \(body)
        </dict>
        </plist>
        """.write(to: plistURL, atomically: true, encoding: .utf8)

        return plistURL
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    func scanner(
        codeSignatureInspector: any CodeSignatureInspecting = FakeCodeSignatureInspector(result: CodeSignatureAssessment(status: .unsigned))
    ) -> PersistenceScanner {
        PersistenceScanner(
            codeSignatureInspector: codeSignatureInspector,
            loginItemInventoryProvider: emptyLoginItemProvider,
            configuration: configuration
        )
    }
}
