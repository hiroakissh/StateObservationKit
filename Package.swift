// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StateObservationKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "StateObservationKit",
            targets: ["StateObservationKit"]
        ),
    ],
    targets: [
        .target(
            name: "StateObservationKit",
            path: "Sources"
        ),
        .testTarget(
            name: "StateObservationKitTests",
            dependencies: ["StateObservationKit"],
            path: "Tests"
        )
    ]
)
