// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "image-embedding-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "image-embedding-feasibility"
        )
    ]
)
