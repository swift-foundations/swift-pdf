// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "testing",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/swift-foundations/swift-testing.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-tests.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-test-primitives.git", branch: "main"),
    ],
    targets: [
        .testTarget(
            name: "PDF Performance Tests",
            dependencies: [
                .product(name: "PDF", package: "swift-pdf"),
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "PDF Performance Tests"
        ),
        .testTarget(
            name: "PDF Snapshot Tests",
            dependencies: [
                .product(name: "PDF", package: "swift-pdf"),
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Tests Inline Snapshot", package: "swift-tests"),
                .product(name: "Test Snapshot Primitives", package: "swift-test-primitives"),
                .product(name: "Test Primitives Test Support", package: "swift-test-primitives"),
            ],
            path: "PDF Snapshot Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
