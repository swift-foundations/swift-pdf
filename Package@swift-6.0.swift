// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// MARK: - String Extensions
extension String {
    static var htmlToPdf: Self { "HtmlToPdf" }
    static var pdfTestSupport: Self { "PDFTestSupport" }
}

// MARK: - Target Dependency Extensions
extension Target.Dependency {
    static var htmlToPdf: Self { .target(name: .htmlToPdf) }
    static var pdfTestSupport: Self { .target(name: .pdfTestSupport) }
}

extension Target.Dependency {
    static var dependencies: Self { .product(name: "Dependencies", package: "swift-dependencies") }
    static var dependenciesMacros: Self { .product(name: "DependenciesMacros", package: "swift-dependencies") }
    static var dependenciesTestSupport: Self { .product(name: "DependenciesTestSupport", package: "swift-dependencies") }
    static var environmentVariables: Self { .product(name: "EnvironmentVariables", package: "swift-environment-variables") }
    static var loggingExtras: Self { .product(name: "LoggingExtras", package: "swift-logging-extras") }
    static var metrics: Self { .product(name: "Metrics", package: "swift-metrics") }
    static var pointFreeHTML: Self { .product(name: "PointFreeHTML", package: "pointfree-html") }
    static var html: Self { .product(name: "HTML", package: "swift-html") }
    static var resourcePool: Self { .product(name: "ResourcePool", package: "swift-resource-pool") }
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
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
        .package(url: "https://github.com/coenttb/swift-environment-variables", from: "0.1.3"),
        .package(url: "https://github.com/coenttb/swift-logging-extras", from: "0.1.1"),
        .package(url: "https://github.com/apple/swift-metrics", from: "2.4.0"),
        .package(url: "https://github.com/coenttb/swift-resource-pool", from: "0.1.0"),
        .package(url: "https://github.com/coenttb/pointfree-html", from: "0.1.0"),
        .package(url: "https://github.com/coenttb/swift-html", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: .htmlToPdf,
            dependencies: [
                .dependencies,
                .dependenciesMacros,
                .environmentVariables,
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
            exclude: [
                "HtmlToPdfLive.xctestplan"
            ],
            resources: [.process("Resources")]
        )
    ],
    swiftLanguageModes: [.v6]
)
