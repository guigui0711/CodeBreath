// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodeBreathApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CodeBreathApp",
            path: "Sources/CodeBreathApp"
        )
    ]
)
