// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "repro-crash",
    dependencies: [
        .package(path: "../base")
    ],
    targets: [
        .target(
            name: "CrashModule",
            dependencies: [
                .product(name: "BasePDF", package: "base")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .target(
            name: "RespellModule",
            dependencies: [
                .product(name: "BasePDF", package: "base")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
