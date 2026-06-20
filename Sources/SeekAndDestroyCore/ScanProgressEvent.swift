//
//  ScanProgressEvent.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import Foundation

public enum ScanProgressEvent: Equatable, Sendable {
    case scannedFile(URL)
    case skippedFile(URL)
    case finding(ScanFinding)
}
