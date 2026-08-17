// swift-tools-version: 6.3.3

import PackageDescription

extension String {
    static let pdf: Self = "PDF"
    var tests: Self { self + " Tests" }
}

extension Target.Dependency {
    static var pdf: Self { .target(name: .pdf) }
}

extension Target.Dependency {
    static var html: Self {
        .product(name: "HTML", package: "swift-html")
    }
    static var pdfHTMLRendering: Self {
        .product(name: "PDF HTML Rendering", package: "swift-pdf-html-render")
    }
    static var fileSystem: Self {
        .product(name: "File System", package: "swift-file-system")
    }
}

let package = Package(
    name: "swift-pdf",
    platforms: [
        .macOS("27"),
        .iOS("27"),
        .tvOS("27"),
        .watchOS("27"),
        .visionOS("27"),
    ],
    products: [
        .library(name: .pdf, targets: [.pdf]),
        .library(name: "PDF Test Support", targets: ["PDF Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-html.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-pdf-html-render.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
    ],
    targets: [
        .target(
            name: .pdf,
            dependencies: [
                .html,
                .pdfHTMLRendering,
                .fileSystem,
            ]
        ),
        .target(
            name: "PDF Test Support",
            dependencies: [
                .pdf,
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: .pdf.tests,
            dependencies: [
                .pdf,
                .html,
                "PDF Test Support",
            ],
            path: "Tests/PDF Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
