//
//  ConfigurationProfileDetails.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public struct ConfigurationProfileDetails: Codable, Equatable, Sendable {
    public let displayName: String?
    public let identifier: String?
    public let uuid: String?
    public let organization: String?
    public let profileDescription: String?
    public let removalDisallowed: Bool?
    public let payloadType: String?
    public let payloadVersion: Int?
    public let payloadCount: Int
    public let payloadTypes: [String]
    public let payloadIdentifiers: [String]

    public init(
        displayName: String? = nil,
        identifier: String? = nil,
        uuid: String? = nil,
        organization: String? = nil,
        profileDescription: String? = nil,
        removalDisallowed: Bool? = nil,
        payloadType: String? = nil,
        payloadVersion: Int? = nil,
        payloadCount: Int = 0,
        payloadTypes: [String] = [],
        payloadIdentifiers: [String] = []
    ) {
        self.displayName = displayName
        self.identifier = identifier
        self.uuid = uuid
        self.organization = organization
        self.profileDescription = profileDescription
        self.removalDisallowed = removalDisallowed
        self.payloadType = payloadType
        self.payloadVersion = payloadVersion
        self.payloadCount = payloadCount
        self.payloadTypes = payloadTypes
        self.payloadIdentifiers = payloadIdentifiers
    }

    public var hasDisplayedValues: Bool {
        displayName != nil
            || identifier != nil
            || uuid != nil
            || organization != nil
            || profileDescription != nil
            || removalDisallowed != nil
            || payloadType != nil
            || payloadVersion != nil
            || payloadCount > 0
            || !payloadTypes.isEmpty
            || !payloadIdentifiers.isEmpty
    }
}
