// swift-tools-version: 6.0
//
//  Package.swift
//  SeekAndDestroy
//
//  Created by Johnson Elangbam on 20/06/26.
//

import PackageDescription

let package = Package(
    name: "SeekAndDestroy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SeekAndDestroyCore",
            targets: ["SeekAndDestroyCore"]
        ),
        .executable(
            name: "seekanddestroy",
            targets: ["seekanddestroy"]
        ),
        .executable(
            name: "SeekAndDestroyApp",
            targets: ["SeekAndDestroyApp"]
        )
    ],
    targets: [
        .target(
            name: "SeekAndDestroyCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "seekanddestroy",
            dependencies: ["SeekAndDestroyCore"]
        ),
        .executableTarget(
            name: "SeekAndDestroyApp",
            dependencies: ["SeekAndDestroyCore"]
        ),
        .testTarget(
            name: "SeekAndDestroyCoreTests",
            dependencies: ["SeekAndDestroyCore"]
        )
    ]
)
