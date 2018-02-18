// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BinanceAPI",
    products: [
        .library(
            name: "BinanceAPI",
            targets: ["BinanceAPI"]),
    ],
    dependencies: [
      .package(url: "https://github.com/Alamofire/Alamofire.git", from: "4.0.0"),
      .package(url: "https://github.com/IBM-Swift/CommonCrypto.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "BinanceAPI",
            dependencies: ["Alamofire", "CommonCrypto"]
        ),
    ]
)
