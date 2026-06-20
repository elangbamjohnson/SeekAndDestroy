//
//  LoginItemDetails.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct LoginItemDetails: Codable, Equatable, Sendable {
    public let displayName: String
    public let bundleIdentifier: String?
    public let teamIdentifier: String?
    public let developerName: String?
    public let itemType: String?
    public let disposition: String?
    public let bundleURL: URL?
    public let executableURL: URL?
    public let rawRecord: String?

    public init(
        displayName: String,
        bundleIdentifier: String? = nil,
        teamIdentifier: String? = nil,
        developerName: String? = nil,
        itemType: String? = nil,
        disposition: String? = nil,
        bundleURL: URL? = nil,
        executableURL: URL? = nil,
        rawRecord: String? = nil
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
        self.developerName = developerName
        self.itemType = itemType
        self.disposition = disposition
        self.bundleURL = bundleURL?.resolvingSymlinksInPath()
        self.executableURL = executableURL?.resolvingSymlinksInPath()
        self.rawRecord = rawRecord
    }
}

public struct LoginItemInventory: Equatable, Sendable {
    public let items: [LoginItemDetails]
    public let status: PersistenceLocationStatus
    public let message: String?

    public init(
        items: [LoginItemDetails],
        status: PersistenceLocationStatus,
        message: String? = nil
    ) {
        self.items = items
        self.status = status
        self.message = message
    }
}

public protocol LoginItemInventoryProviding {
    func inventoryLoginItems() -> LoginItemInventory
}
