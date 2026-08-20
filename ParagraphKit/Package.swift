// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParagraphKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ParagraphKit", targets: ["ParagraphKit"])
    ],
    targets: [
        .target(name: "ParagraphKit"),
        .testTarget(name: "ParagraphKitTests", dependencies: ["ParagraphKit"])
    ]
)
