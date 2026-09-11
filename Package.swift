// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SideDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SideDeck", targets: ["SideDeck"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SideDeck",
            dependencies: [],
            path: "Sources/SideDeck"
        )
    ]
)
