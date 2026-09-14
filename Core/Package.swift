// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CardCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "CardCore", targets: ["CardCore"])],
    targets: [.target(name: "CardCore"), .testTarget(name: "CardCoreTests", dependencies: ["CardCore"])]
)
