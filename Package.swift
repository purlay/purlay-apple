// swift-tools-version: 6.2
import PackageDescription

// Every module of the Apple apps, in one package, so that the floors and the strictness are stated once.
// Swift 6 language mode and every warning an error, for every target. The floors are the apps' own: iOS 18 for the iPhone and
// iPad, macOS 26 for the Mac. Config/iOS.xcconfig and Config/macOS.xcconfig state the same numbers (scripts/enforcement).
let strict: [SwiftSetting] = [.treatAllWarnings(as: .error)]

func module(_ name: String, _ dependencies: [Target.Dependency] = [], resources: [Resource]? = nil) -> Target {
    .target(name: name, dependencies: dependencies, resources: resources, swiftSettings: strict)
}

func tests(_ name: String, _ dependencies: [Target.Dependency]) -> Target {
    .testTarget(name: name, dependencies: dependencies, swiftSettings: strict)
}

let package = Package(
    name: "purlay-apple",
    // English is the source language of every catalogue; PurlayWords carries its own.
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v26)],
    products: [
        .library(name: "PurlayContract", targets: ["PurlayContract"]),
        .library(name: "PurlayTokens", targets: ["PurlayTokens"]),
        .library(name: "PurlayKit", targets: ["PurlayKit"]),
        .library(name: "PurlayWords", targets: ["PurlayWords"]),
        .library(name: "PurlayTestSupport", targets: ["PurlayTestSupport"]),
        .library(name: "PurlayDesign", targets: ["PurlayDesign"]),
        .library(name: "PurlayModuleAPI", targets: ["PurlayModuleAPI"]),
        .library(name: "PurlayMacUI", targets: ["PurlayMacUI"]),
        .library(name: "FeatureChat", targets: ["FeatureChat"]),
    ],
    targets: [
        // Generated from the server's contract bundle (scripts/generate); never edited by hand.
        module("PurlayContract"),
        module("PurlayTokens"),
        // The engine: no UI framework.
        module("PurlayKit", ["PurlayContract"]),
        // What both apps say about what the engine reports, translated once in its own catalogue.
        module(
            "PurlayWords", ["PurlayKit", "PurlayContract"], resources: [.process("Resources/Localizable.xcstrings")]),
        module("PurlayTestSupport", ["PurlayKit", "PurlayContract"]),
        // The design system: the only place an OS version is asked about.
        module("PurlayDesign", ["PurlayTokens"]),
        module("PurlayModuleAPI"),
        // Today's Mac screens, moved into features one by one.
        module("PurlayMacUI", ["PurlayKit", "PurlayContract", "PurlayTokens", "PurlayWords"]),
        // The chat module's screens: the workspace's channels and their feeds.
        module("FeatureChat", ["PurlayModuleAPI", "PurlayKit", "PurlayContract"]),

        tests("PurlayContractTests", ["PurlayContract"]),
        tests("PurlayTokensTests", ["PurlayTokens"]),
        tests("PurlayKitTests", ["PurlayKit", "PurlayTestSupport"]),
        tests("PurlayTestSupportTests", ["PurlayTestSupport", "PurlayKit", "PurlayContract"]),
        tests("PurlayDesignTests", ["PurlayDesign"]),
        tests("PurlayModuleAPITests", ["PurlayModuleAPI"]),
        tests("PurlayWordsTests", ["PurlayWords", "PurlayKit", "PurlayContract"]),
        tests("FeatureChatTests", ["FeatureChat", "PurlayContract"]),
        tests("PurlayMacUITests", ["PurlayMacUI", "PurlayKit", "PurlayContract", "PurlayTokens", "PurlayTestSupport"]),
        // The real client against a real server of the pinned version (§16.3): skipped, and saying so, without one;
        // scripts/contract-test starts one. Compiled in every pull request, so a change that breaks them is seen there.
        tests("ContractTests", ["PurlayContract", "PurlayKit", "PurlayTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
