// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "result-builder-stack-overflow",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "result-builder-stack-overflow",
            dependencies: [
                .product(name: "PDF", package: "swift-pdf"),
            ]
        )
    ]
)
