// swift-tools-version: 6.3.3
// Crash package for the cross-package debug-info-mangler repro.
// Extends the OTHER package's typealias-sugared namespace with nested
// protocols and forms their existentials at a debug-info-emitting site
// (mirrors swift-pdf-html-render). Cross-PACKAGE is a load-bearing
// ingredient per swiftlang/swift#86202: the same shape cross-module
// within one package does not crash.
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
