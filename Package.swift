// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SendablePublishers",
  platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .macCatalyst(.v15), .watchOS(.v9), .visionOS(.v1)],
  products: [
    .library(name: "SendablePublishers", targets: ["SendablePublishers"]),
  ],
  targets: [
    .target(name: "SendablePublishers", swiftSettings: [
      .enableUpcomingFeature("ApproachableConcurrency"),
    ]),
    .testTarget(name: "SendablePublishersTests",
                dependencies: ["SendablePublishers"],
                swiftSettings: [
                  .enableUpcomingFeature("ApproachableConcurrency"),
                ]),
  ],
  swiftLanguageModes: [.v6],
)

for target: PackageDescription.Target in package.targets {
  {
    var settings: [PackageDescription.SwiftSetting] = $0 ?? []
    settings.append(.enableUpcomingFeature("ExistentialAny"))
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))
    
    $0 = settings
  }(&target.swiftSettings)
}
