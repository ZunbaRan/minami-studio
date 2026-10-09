// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "minami-studio",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "minami-studio",
            path: "Sources/minami-studio"
        )
    ]
)
