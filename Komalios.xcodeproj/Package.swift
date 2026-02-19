// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ExamplePackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/example/MyLib.git", branch: "main"),
        .package(url: "https://github.com/example/AnotherLib.git", revision: "abcdef1234567890"),
        .package(url: "https://github.com/example/ExactLib.git", exact: "2.1.0"),
        .package(url: "https://github.com/example/UpToNextMajorLib.git", from: "3.0.0"),
        .package(url: "https://github.com/example/UpToNextMinorLib.git", .upToNextMinor(from: "1.2.0")),
    ]
)
