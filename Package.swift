// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CodexBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CodexBar", targets: ["CodexBar"])],
    targets: [
        .executableTarget(name: "CodexBar"),
        .testTarget(name: "CodexBarTests", dependencies: ["CodexBar"])
    ],
    swiftLanguageVersions: [.v5]
)
