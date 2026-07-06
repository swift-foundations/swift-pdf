// swift-tools-version: 6.1
// Base package for the cross-package debug-info-mangler repro.
// Provides the spec namespace root + the load-bearing namespace TYPEALIAS
// (mirrors swift-pdf-standard's `public typealias PDF = ISO_32000`).
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
