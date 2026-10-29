// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DUOCore", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "DUOCore", targets: ["DUOCore"])], targets: [.target(name: "DUOCore", path: "Core"), .testTarget(name: "DUOCoreTests", dependencies: ["DUOCore"], path: "Tests")])
