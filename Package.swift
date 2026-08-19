// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Klack",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Klack",
            linkerSettings: [.linkedFramework("Carbon")]
        ),
    ]
)
