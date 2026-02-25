// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Komalios",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Komalios", targets: ["Komalios"])
    ],
    dependencies: [
        // Firebase dependencies
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.8.0"),
        // Google Sign-In
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.1.0")
    ],
    targets: [
        .target(
            name: "Komalios",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
            ],
            path: "Sources/Komalios",
            resources: [
                .process("Resources"),
                .process("Assets.xcassets"),
                .process("PrivacyInfo.xcprivacy"),
                .process("animal1.png"),
                .process("animal2.png"),
                .process("animal3.png"),
                .process("animal4.png"),
                .process("animal5.png"),
                .process("animal6.png"),
                .process("animal7.png"),
                .process("animal8.png"),
                .process("animal9.png"),
                .process("animal10.png"),
                .process("animal11.png")
            ]
        ),
        .testTarget(
            name: "KomaliosTests",
            dependencies: ["Komalios"],
            path: "Tests/KomaliosTests"
        )
    ]
)
