// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeMeter",
    platforms: [ .macOS(.v14) ],
    products: [
        .executable(name: "ClaudeMeter", targets: ["ClaudeMeter"]),
        .library(name: "ClaudeMeterCore", targets: ["ClaudeMeterCore"])
    ],
    targets: [
        .target(name: "ClaudeMeterCore"),
        .executableTarget(name: "ClaudeMeter", dependencies: ["ClaudeMeterCore"])
    ]
)
