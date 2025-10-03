// swift-tools-version: 6.0

import PackageDescription

// MARK: - String Extensions
extension String {
    static var htmlToPdfTypes: Self { "HtmlToPdfTypes" }
    static var htmlToPdfLive: Self { "HtmlToPdfLive" }
    static var htmlToPdf: Self { "HtmlToPdf" }
    static var pdfTestSupport: Self { "PDFTestSupport" }
    static var dependencies: Self { "Dependencies" }
    static var dependenciesMacros: Self { "DependenciesMacros" }
    static var dependenciesTestSupport: Self { "DependenciesTestSupport" }
    static var loggingExtras: Self { "LoggingExtras" }
    static var metrics: Self { "Metrics" }
    static var pointFreeHTML: Self { "PointFreeHTML" }
    static var resourcePool: Self { "ResourcePool" }
}

// MARK: - Package Dependency Extensions
extension Package.Dependency {
    static var swiftDependencies: Package.Dependency { .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0") }
    static var swiftLoggingExtras: Package.Dependency { .package(url: "https://github.com/coenttb/swift-logging-extras", from: "0.0.1") }
    static var swiftMetrics: Package.Dependency { .package(url: "https://github.com/apple/swift-metrics", from: "2.4.0") }
    static var swiftResourcePool: Package.Dependency { .package(path: "../swift-resource-pool") }
    static var pointfreeHtml: Package.Dependency { .package(path: "../pointfree-html") }
}

// MARK: - Target Dependency Extensions
extension Target.Dependency {
    static var htmlToPdfTypes: Self { .target(name: .htmlToPdfTypes) }
    static var htmlToPdfLive: Self { .target(name: .htmlToPdfLive) }
    static var htmlToPdf: Self { .target(name: .htmlToPdf) }
    static var pdfTestSupport: Self { .target(name: .pdfTestSupport) }
    static var dependencies: Self { .product(name: .dependencies, package: "swift-dependencies") }
    static var dependenciesMacros: Self { .product(name: .dependenciesMacros, package: "swift-dependencies") }
    static var dependenciesTestSupport: Self { .product(name: .dependenciesTestSupport, package: "swift-dependencies") }
    static var loggingExtras: Self { .product(name: .loggingExtras, package: "swift-logging-extras") }
    static var metrics: Self { .product(name: .metrics, package: "swift-metrics") }
    static var pointFreeHTML: Self { .product(name: .pointFreeHTML, package: "pointfree-html") }
    static var resourcePool: Self { .product(name: .resourcePool, package: "swift-resource-pool") }
}

let package = Package(
    name: "swift-html-to-pdf",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: .htmlToPdfTypes,
            targets: [.htmlToPdfTypes]
        ),
        .library(
            name: .htmlToPdfLive,
            targets: [.htmlToPdfLive]
        ),
        .library(
            name: .htmlToPdf,
            targets: [.htmlToPdf]
        ),
        .library(
            name: .pdfTestSupport,
            targets: [.pdfTestSupport]
        )
    ],
    dependencies: [
        .swiftDependencies,
        .swiftLoggingExtras,
        .swiftMetrics,
        .swiftResourcePool,
        .pointfreeHtml,
    ],
    targets: [
        // Types target - NO PointFreeHTML dependency
        .target(
            name: .htmlToPdfTypes,
            dependencies: [
                .dependencies,
                .dependenciesMacros
            ]
        ),

        // Live target - NO PointFreeHTML dependency
        .target(
            name: .htmlToPdfLive,
            dependencies: [
                .htmlToPdfTypes,
                .dependencies,
                .dependenciesMacros,
                .loggingExtras,
                .metrics,
                .resourcePool
            ]
        ),

        // Umbrella + Integration target - ADDS PointFreeHTML
        .target(
            name: .htmlToPdf,
            dependencies: [
                .htmlToPdfLive,
                .pointFreeHTML
            ]
        ),

        .target(
            name: .pdfTestSupport,
            dependencies: [
                .htmlToPdfTypes,
                .dependencies,
                .metrics
            ]
        ),

        .testTarget(
            name: .htmlToPdfTypes + "Tests",
            dependencies: [
                .htmlToPdfTypes,
                .dependenciesTestSupport
            ]
        ),

        .testTarget(
            name: .htmlToPdfLive + "Tests",
            dependencies: [
                .htmlToPdfLive,
                .pdfTestSupport,
                .dependenciesTestSupport
            ],
            exclude: ["HtmlToPdf.xctestplan"],
            resources: [.process("Resources")]
        ),

        .testTarget(
            name: .htmlToPdf + "Tests",
            dependencies: [
                .htmlToPdf,
                .pdfTestSupport,
                .dependenciesTestSupport
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
