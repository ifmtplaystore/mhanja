// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MHanja",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MHanja",
            path: "Sources/MHanja",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
