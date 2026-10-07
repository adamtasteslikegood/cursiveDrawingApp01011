// swift-tools-version: 5.8
import PackageDescription

let package = Package(
  name: "CursiveValidation",
  platforms: [.iOS(.v16)],
  targets: [
    .testTarget(
      name: "AnalyzerTests", resources: [.copy("Guides"), .copy("Fixtures")],
      swiftSettings: [.define("CURSIVE_TESTS")])
  ]
)
