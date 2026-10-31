// swift-tools-version: 6.0
import PackageDescription

// The Kotlin core is built by Gradle (`make core`) and dropped into Frameworks/ as a static XCFramework.
let package = Package(
    name: "AVDStudio",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AVDStudioUI", targets: ["AVDStudioUI"]),
        .library(name: "AVDStudioKit", targets: ["AVDStudioKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.0"),
    ],
    targets: [
        .binaryTarget(name: "AVDStudioCore", path: "Frameworks/AVDStudioCore.xcframework"),

        // Pure SwiftUI: models, view models and views. Knows nothing about Kotlin, so it is easy to test.
        .target(name: "AVDStudioUI"),

        // The only place that imports the Kotlin framework; maps its types to the UI's Swift types.
        .target(name: "AVDStudioKit", dependencies: ["AVDStudioCore", "AVDStudioUI"]),

        .testTarget(name: "AVDStudioUITests", dependencies: ["AVDStudioUI"]),
        .testTarget(
            name: "AVDStudioSnapshotTests",
            dependencies: [
                "AVDStudioUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        ),
        .testTarget(name: "AVDStudioKitTests", dependencies: ["AVDStudioKit", "AVDStudioUI", "AVDStudioCore"]),
    ]
)
