// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCProxy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CCProxy",
            targets: ["CCProxy"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "CCProxy",
            dependencies: ["Sparkle"],
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "CCProxyTests",
            dependencies: ["CCProxy"],
            path: "Tests/CCProxyTests"
        )
    ]
)
