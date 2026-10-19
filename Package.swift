// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicBox",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DynamicBox", targets: ["DynamicBox"])
    ],
    targets: [
        .executableTarget(
            name: "DynamicBox",
            path: "Sources"
        )
    ]
)
