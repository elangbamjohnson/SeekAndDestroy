//
//  PersistenceBaseline.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct PersistenceBaseline: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let items: [PersistenceBaselineItem]

    public init(generatedAt: Date = Date(), items: [PersistenceBaselineItem]) {
        self.generatedAt = generatedAt
        self.items = items
    }

    public init(generatedAt: Date = Date(), persistenceItems: [PersistenceItem]) {
        self.generatedAt = generatedAt
        self.items = persistenceItems.map(PersistenceBaselineItem.init(item:))
    }

    public var itemsByID: [String: PersistenceBaselineItem] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }
}

public struct PersistenceBaselineItem: Codable, Equatable, Sendable {
    public let id: String
    public let kind: PersistenceItemKind
    public let label: String
    public let sourcePath: String?
    public let executablePath: String?
    public let contentSHA256: String?
    public let executableSHA256: String?

    public init(item: PersistenceItem) {
        self.id = item.id
        self.kind = item.kind
        self.label = item.label
        self.sourcePath = item.sourceURL?.path
        self.executablePath = item.executablePath
        self.contentSHA256 = item.contentSHA256
        self.executableSHA256 = item.executableSHA256
    }
}

public struct PersistenceBaselineStore {
    private let fileManager: FileManager
    public let baselineURL: URL

    public init(
        fileManager: FileManager = .default,
        baselineURL: URL = PersistenceBaselineStore.defaultBaselineURL()
    ) {
        self.fileManager = fileManager
        self.baselineURL = baselineURL
    }

    public func load() throws -> PersistenceBaseline? {
        guard fileManager.fileExists(atPath: baselineURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: baselineURL)
        return try JSONDecoder.persistenceDecoder.decode(PersistenceBaseline.self, from: data)
    }

    public func save(_ baseline: PersistenceBaseline) throws {
        let directoryURL = baselineURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try JSONEncoder.persistenceEncoder.encode(baseline)
        try data.write(to: baselineURL, options: [.atomic])
    }

    public static func defaultBaselineURL() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return appSupportURL
            .appendingPathComponent("SeekAndDestroy", isDirectory: true)
            .appendingPathComponent("persistence-baseline.json")
    }
}

private extension JSONEncoder {
    static var persistenceEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var persistenceDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
