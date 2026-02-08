// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepAgentsUI",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DeepAgentsUI",
            targets: ["DeepAgentsUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/livekit/client-sdk-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "DeepAgentsUI",
            dependencies: [
                "SwiftyJSON",
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "LiveKit", package: "client-sdk-swift"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "DeepAgentsUITests",
            dependencies: ["DeepAgentsUI"]
        ),
    ]
)
