//
//  SystemLoginItemInventoryProvider.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct SystemLoginItemInventoryProvider: LoginItemInventoryProviding {
    private let sfltoolURL: URL

    public init(sfltoolURL: URL = URL(fileURLWithPath: "/usr/bin/sfltool")) {
        self.sfltoolURL = sfltoolURL
    }

    public func inventoryLoginItems() -> LoginItemInventory {
        guard FileManager.default.fileExists(atPath: sfltoolURL.path) else {
            return LoginItemInventory(
                items: [],
                status: .missing,
                message: "\(sfltoolURL.path) was not found"
            )
        }

        let process = Process()
        process.executableURL = sfltoolURL
        process.arguments = ["dumpbtm"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let outputReaders = DispatchGroup()
        let output = PipeOutputBuffer()
        let errorOutput = PipeOutputBuffer()

        outputReaders.enter()
        DispatchQueue.global(qos: .utility).async {
            output.store(stdout.fileHandleForReading.readDataToEndOfFile())
            outputReaders.leave()
        }

        outputReaders.enter()
        DispatchQueue.global(qos: .utility).async {
            errorOutput.store(stderr.fileHandleForReading.readDataToEndOfFile())
            outputReaders.leave()
        }

        do {
            try process.run()
            process.waitUntilExit()
            outputReaders.wait()
        } catch {
            try? stdout.fileHandleForWriting.close()
            try? stderr.fileHandleForWriting.close()
            try? stdout.fileHandleForReading.close()
            try? stderr.fileHandleForReading.close()
            outputReaders.wait()

            return LoginItemInventory(
                items: [],
                status: .unreadable,
                message: error.localizedDescription
            )
        }

        let outputText = String(data: output.data, encoding: .utf8) ?? ""
        let errorText = String(data: errorOutput.data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let combinedMessage = [outputText, errorText]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
            let status: PersistenceLocationStatus = combinedMessage.localizedCaseInsensitiveContains("authorization")
                ? .permissionDenied
                : .unreadable

            return LoginItemInventory(
                items: [],
                status: status,
                message: combinedMessage.isEmpty ? "sfltool exited with status \(process.terminationStatus)" : combinedMessage
            )
        }

        return LoginItemInventory(
            items: LoginItemDumpParser.parse(outputText),
            status: .scanned
        )
    }
}

private final class PipeOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storedData = Data()

    var data: Data {
        lock.withLock {
            storedData
        }
    }

    func store(_ data: Data) {
        lock.withLock {
            storedData = data
        }
    }
}

public enum LoginItemDumpParser {
    public static func parse(_ output: String) -> [LoginItemDetails] {
        records(from: output).compactMap(parseRecord)
    }

    private static func records(from output: String) -> [String] {
        output
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseRecord(_ record: String) -> LoginItemDetails? {
        let fields = fields(from: record)
        let name = firstValue(in: fields, keys: ["Name", "Display Name", "Item Name", "Label"])
            ?? firstValue(in: fields, keys: ["Bundle Identifier", "Identifier", "Bundle ID"])

        guard let displayName = name, !displayName.isEmpty else {
            return nil
        }

        return LoginItemDetails(
            displayName: displayName,
            bundleIdentifier: firstValue(in: fields, keys: ["Bundle Identifier", "Bundle ID", "Identifier"]),
            teamIdentifier: firstValue(in: fields, keys: ["Team Identifier", "Team ID"]),
            developerName: firstValue(in: fields, keys: ["Developer Name", "Developer"]),
            itemType: firstValue(in: fields, keys: ["Type", "Item Type"]),
            disposition: firstValue(in: fields, keys: ["Disposition", "Status"]),
            bundleURL: urlValue(firstValue(in: fields, keys: ["Bundle URL", "URL", "Container URL"])),
            executableURL: urlValue(firstValue(in: fields, keys: ["Executable URL", "Executable Path", "Path"])),
            rawRecord: record
        )
    }

    private static func fields(from record: String) -> [String: String] {
        record.split(whereSeparator: \.isNewline).reduce(into: [:]) { result, line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                return
            }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else {
                return
            }

            result[key] = value
        }
    }

    private static func firstValue(in fields: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = fields[key] {
                return value
            }
        }

        return nil
    }

    private static func urlValue(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else {
            return nil
        }

        if value.hasPrefix("file://"), let url = URL(string: value) {
            return url
        }

        guard value.hasPrefix("/") || value.hasPrefix("~") else {
            return nil
        }

        return URL(fileURLWithPath: (value as NSString).expandingTildeInPath)
    }
}
