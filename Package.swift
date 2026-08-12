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
        .executable(
            name: "StateObservationKitTimerExample",
            targets: ["StateObservationKitTimerExample"]
        ),
    ],
    targets: [
        .target(
            name: "StateObservationKit",
            path: "Sources"
        ),
        .executableTarget(
            name: "StateObservationKitTimerExample",
            dependencies: ["StateObservationKit"],
            path: "Examples/TimerApp",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "StateObservationKitTests",
            dependencies: ["StateObservationKit"],
            path: "Tests"
        )
    ]
)
