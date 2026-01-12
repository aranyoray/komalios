// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Komalios",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(name: "Komalios", targets: ["Komalios"])
    ],
    targets: [
        .executableTarget(
            name: "Komalios",
            path: "Sources/Komalios",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
