// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "SendableCombine",
  platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .macCatalyst(.v18), .watchOS(.v11), .visionOS(.v2)],
  products: [
    .library(name: "SendableCombine", targets: ["SendableCombine"]),
    .library(name: "SendablePublishers", targets: ["SendablePublishers"]),
    .library(name: "MainActorPublishers", targets: ["MainActorPublishers"]),
    .library(name: "CurrentValuePublisher", targets: ["CurrentValuePublisher"]),
    .library(name: "CancellationBag", targets: ["CancellationBag"]),
  ],
  targets: [
    .target(name: "SendablePublishers"),
    .target(name: "CancellationBag",
            dependencies: ["SendableCombineLogging"],
            swiftSettings: [
              .enableExperimentalFeature("StaticExclusiveOnly"),
              .unsafeFlags(["-Xfrontend", "-disable-reflection-metadata"], .when(configuration: .release)),
            ]),
    .target(name: "SendableCombineLogging",
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-reflection-metadata"], .when(configuration: .release))]),
    .target(name: "CurrentValuePublisher",
            dependencies: ["SendablePublishers"]),
    .target(name: "MainActorPublishers",
            dependencies: ["SendablePublishers","SendableCombineLogging"]),
    .target(name: "SendableCombine",
            dependencies: [
              "SendablePublishers",
              "CancellationBag",
              "CurrentValuePublisher",
              "MainActorPublishers",
            ]),
    
    // MARK: - Test Targets
    
    .testTarget(name: "SendablePublishersTests",
                dependencies: ["SendablePublishers"]),
    .testTarget(name: "CancellationBagTests",
                dependencies: ["CancellationBag"]),
    .testTarget(name: "CurrentValuePublisherTests",
                dependencies: ["CurrentValuePublisher"]),
    .testTarget(name: "MainActorPublishersTests",
                dependencies: [
                  "MainActorPublishers",
                  "SendableCombineLogging",
                ]),
    .testTarget(name: "SendableCombineTests", dependencies: ["SendableCombine"]),
  ],
  swiftLanguageModes: [.v6],
)

for target: PackageDescription.Target in package.targets {
  {
    var settings: [PackageDescription.SwiftSetting] = $0 ?? []
    settings.append(.enableUpcomingFeature("ExistentialAny"))
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))
    settings.append(.enableUpcomingFeature("ApproachableConcurrency"))
    
    $0 = settings
  }(&target.swiftSettings)
}
