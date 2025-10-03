// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// MARK: - String Extensions
extension String {
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
        .target(
            name: .htmlToPdf,
            dependencies: [
                .dependencies,
                .dependenciesMacros,
                .loggingExtras,
                .metrics,
                .resourcePool,
                .pointFreeHTML
            ]
        ),
        .target(
            name: .pdfTestSupport,
            dependencies: [
                .htmlToPdf,
                .dependencies,
                .metrics
            ]
        ),
        .testTarget(
            name: .htmlToPdf + "Tests",
            dependencies: [
                .htmlToPdf,
                .pdfTestSupport,
                .dependenciesTestSupport
            ],
            exclude: ["HtmlToPdf.xctestplan"],
            resources: [.process("Resources")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
