// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MacPerformance",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MacPerformance", targets: ["MacPerformance"])
    ],
    targets: [
        .executableTarget(
            name: "MacPerformance",
            path: "Sources/MacPerformance",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
