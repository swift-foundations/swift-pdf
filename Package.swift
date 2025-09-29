// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

extension String {
    static var htmlToPdf: Self { "HtmlToPdf" }
    static var dependencies: Self { "Dependencies" }
}

extension Target.Dependency {
    static var htmlToPdf: Self { .target(name: .htmlToPdf) }
    static var dependencies: Self { .product(name: .dependencies, package: .dependencies) }
}

let package = Package(
    name: "swift-html-to-pdf",
    platforms: [.macOS(.v11), .iOS(.v14)],
    products: [
        .library(
            name: .htmlToPdf,
            targets: [.htmlToPdf]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: .htmlToPdf,
            dependencies: [
                .dependencies
            ]
        ),
        .testTarget(
            name: .htmlToPdf + "Tests",
            dependencies: [.htmlToPdf],
            exclude: ["HtmlToPdf.xctestplan"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
