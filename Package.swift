// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "minami-computer-use",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "minami-computer-use",
            path: "Sources/minami-computer-use"
        )
    ]
)
