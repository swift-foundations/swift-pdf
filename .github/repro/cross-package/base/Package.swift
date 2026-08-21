// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "repro-base",
    products: [
        .library(name: "BasePDF", targets: ["BasePDF"])
    ],
    targets: [
        .target(
            name: "BasePDF",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
