// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Ember",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Ember",
            path: "Sources/Ember",
            exclude: ["Info.plist"]
        )
    ]
)
