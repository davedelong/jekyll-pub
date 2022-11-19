// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "jekyll-pub",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "jekyll-pub", targets: ["jekyll-pub"])
    ],
    dependencies: [
        .package(url: "https://github.com/httpswift/Swifter.git", .upToNextMajor(from: "1.4.7")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "3.0.1"),
    ],
    targets: [
        .target(name: "jekyll-pub", dependencies: [
            "Swifter",
            "Yams"
        ]),
    ]
)
