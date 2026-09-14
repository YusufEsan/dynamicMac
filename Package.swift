// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FaceIsland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FaceIsland",
            targets: ["FaceIsland"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FaceIsland",
            path: "Sources/FaceIsland",
            exclude: [
                "Info.plist",
                "FaceIsland.entitlements"
            ]
        )
    ]
)
