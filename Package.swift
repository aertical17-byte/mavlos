// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mavlos",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MavlosCore",
            path: "Sources/MavlosCore"
        ),
        .executableTarget(
            name: "Mavlos",
            dependencies: ["MavlosCore"],
            path: "Sources/Mavlos"
        ),
        .testTarget(
            name: "MavlosCoreTests",
            dependencies: ["MavlosCore"],
            path: "Tests/MavlosCoreTests"
        )
    ]
)
