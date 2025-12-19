// swift-tools-version: 6.2

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
    static var html: Self { "HTML" }
    static var resourcePool: Self { "ResourcePool" }
}

// MARK: - Target Dependency Extensions
extension Target.Dependency {
    static var htmlToPdfTypes: Self { .target(name: .htmlToPdfTypes) }
    static var htmlToPdfLive: Self { .target(name: .htmlToPdfLive) }
    static var htmlToPdf: Self { .target(name: .htmlToPdf) }
    static var pdfTestSupport: Self { .target(name: .pdfTestSupport) }
}

extension Target.Dependency {
    static var dependencies: Self { .product(name: .dependencies, package: "swift-dependencies") }
    static var dependenciesMacros: Self {
        .product(name: .dependenciesMacros, package: "swift-dependencies")
    }
    static var dependenciesTestSupport: Self {
        .product(name: .dependenciesTestSupport, package: "swift-dependencies")
    }
    static var loggingExtras: Self {
        .product(name: .loggingExtras, package: "swift-logging-extras")
    }
    static var metrics: Self { .product(name: .metrics, package: "swift-metrics") }
    static var resourcePool: Self { .product(name: .resourcePool, package: "swift-resource-pool") }
    static var html: Self { .product(name: .html, package: "swift-html") }
}

// MARK: - Package Dependencies (to help compiler with traits complexity)
extension Package.Dependency {
    static var swiftDependencies: Package.Dependency {
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0")
    }
    static var swiftLoggingExtras: Package.Dependency {
        .package(url: "https://github.com/coenttb/swift-logging-extras", from: "0.1.1")
    }
    static var swiftMetrics: Package.Dependency {
        .package(url: "https://github.com/apple/swift-metrics", from: "2.4.0")
    }
    static var swiftResourcePool: Package.Dependency {
        .package(url: "https://github.com/coenttb/swift-resource-pool", from: "0.1.1")
    }
    static var swiftHtml: Package.Dependency {
        .package(url: "https://github.com/coenttb/swift-html", from: "0.11.1")
    }
}

let package = Package(
    name: "swift-html-to-pdf",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [
        .library(name: .htmlToPdfTypes, targets: [.htmlToPdfTypes]),
        .library(name: .htmlToPdfLive, targets: [.htmlToPdfLive]),
        .library(name: .htmlToPdf, targets: [.htmlToPdf]),
        .library(name: .pdfTestSupport, targets: [.pdfTestSupport]),
    ],
    traits: [
        .trait(
            name: "HTML",
            description: "Include HTML integration (swift-html with PointFreeHTML)"
        )  //        .default(enabledTraits: ["HTML"])
    ],
    dependencies: [
        .swiftDependencies, .swiftLoggingExtras, .swiftMetrics, .swiftResourcePool, .swiftHtml,
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Types target - NO PointFreeHTML dependency
        .target(name: .htmlToPdfTypes, dependencies: [.dependencies, .dependenciesMacros]),

        // Live target - NO PointFreeHTML dependency
        .target(
            name: .htmlToPdfLive,
            dependencies: [
                .htmlToPdfTypes, .dependencies, .dependenciesMacros, .loggingExtras, .metrics,
                .resourcePool,
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),

        // Umbrella + Integration target - ADDS swift-html (conditionally)
        .target(
            name: .htmlToPdf,
            dependencies: [
                .htmlToPdfLive,
                .product(name: .html, package: "swift-html", condition: .when(traits: ["HTML"])),
            ],
            swiftSettings: [.define("HTML", .when(traits: ["HTML"]))]
        ),

        .target(name: .pdfTestSupport, dependencies: [.htmlToPdfTypes, .dependencies, .metrics]),

        .testTarget(
            name: .htmlToPdfTypes.tests,
            dependencies: [.htmlToPdfTypes, .dependenciesTestSupport],
            exclude: ["HtmlToPdfTypes.xctestplan"],
        ),

        .testTarget(
            name: .htmlToPdfLive.tests,
            dependencies: [.htmlToPdfLive, .pdfTestSupport, .dependenciesTestSupport],
            exclude: ["HtmlToPdfLive.xctestplan", "StressTestLogs"],
            resources: [.process("Resources")]
        ),

        .testTarget(
            name: .htmlToPdf.tests,
            dependencies: [.htmlToPdf, .pdfTestSupport, .dependenciesTestSupport],
            exclude: ["HtmlToPdf.xctestplan"],
            swiftSettings: [.define("HTML", .when(traits: ["HTML"]))]
        ),
    ]
)

extension String { var tests: Self { self + "Tests" } }
