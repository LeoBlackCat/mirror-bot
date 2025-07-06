// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MirrorBot",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MirrorBot",
            dependencies: [],
            path: "MirrorBot"
        )
    ]
)