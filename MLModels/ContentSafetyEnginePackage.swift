// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContentSafetyEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ContentSafetyEngine",
            targets: ["ContentSafetyEngine"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ContentSafetyEngine",
            dependencies: [],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "ContentSafetyEngineTests",
            dependencies: ["ContentSafetyEngine"]),
    ]
)
