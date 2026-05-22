// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Codnia",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Codnia", targets: ["Codnia"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.18.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Codnia",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
            ],
            exclude: [
                "Info.plist",
                "icon.png"
            ],
            resources: [
                .process("icon.icns"),
                .process("Resources"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "CodniaTests",
            dependencies: ["Codnia"]
        ),
    ]
)
