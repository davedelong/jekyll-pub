// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "jekyll-pub",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "jekyll-pub", targets: ["jekyll-pub"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnsundell/Ink.git", from: "0.1.0"),
        .package(url: "https://github.com/httpswift/Swifter.git", .upToNextMajor(from: "1.4.7")),
    ],
    targets: [
        .target(name: "jekyll-pub", dependencies: [
            "Ink",
            "Swifter",
        ]),
    ]
)
