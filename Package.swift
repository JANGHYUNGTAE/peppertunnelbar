// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TunnelBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TunnelBar",
            path: "Sources/TunnelBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
