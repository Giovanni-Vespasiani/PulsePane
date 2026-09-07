// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PulsePane",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "PulsePane", targets: ["PulsePane"])
    ],
    targets: [
        .executableTarget(
            name: "PulsePane",
            path: "Sources/PulsePane",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(
            name: "PulsePaneTests",
            dependencies: ["PulsePane"],
            path: "Tests/PulsePaneTests",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)