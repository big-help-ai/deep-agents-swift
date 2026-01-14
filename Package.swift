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
    ],
    targets: [
        .target(
            name: "DeepAgentsUI",
            dependencies: [
                "SwiftyJSON",
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "DeepAgentsUITests",
            dependencies: ["DeepAgentsUI"]
        ),
    ]
)
