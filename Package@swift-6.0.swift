// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

extension String {
    static var htmlToPdf: Self { "HtmlToPdf" }
    static var dependencies: Self { "Dependencies" }
    static var dependenciesMacros: Self { "DependenciesMacros" }
    static var environmentVariables: Self { "EnvironmentVariables" }
}

extension Target.Dependency {
    static var htmlToPdf: Self { .target(name: .htmlToPdf) }
    static var dependencies: Self { .product(name: .dependencies, package: "swift-dependencies") }
    static var dependenciesMacros: Self { .product(name: .dependenciesMacros, package: "swift-dependencies") }
    static var environmentVariables: Self { .product(name: "EnvironmentVariables", package: "swift-environment-variables") }
}

let package = Package(
    name: "swift-html-to-pdf",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: .htmlToPdf,
            targets: [.htmlToPdf]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
        .package(url: "https://github.com/coenttb/swift-environment-variables", from: "0.1.3"),
        .package(path: "../swift-resource-pool"),
    ],
    targets: [
        .target(
            name: .htmlToPdf,
            dependencies: [
                .dependencies,
                .dependenciesMacros,
                .environmentVariables,
                .product(name: "ResourcePool", package: "swift-resource-pool")
            ]
        ),
        .testTarget(
            name: .htmlToPdf + "Tests",
            dependencies: [
                .htmlToPdf,
                .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            ],
            exclude: ["HtmlToPdf.xctestplan"]
        )
    ],
    swiftLanguageModes: [.v6]
)
