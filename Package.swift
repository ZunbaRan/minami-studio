// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "agent-computer-use",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "agent-computer-use",
            path: "Sources/agent-computer-use"
        )
    ]
)
