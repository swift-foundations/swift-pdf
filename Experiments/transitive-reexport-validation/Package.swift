// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "transitive-reexport-validation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "transitive-reexport-validation"
        )
    ]
)
