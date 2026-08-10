// swift-tools-version: 6.0
import PackageDescription

/// MediaAlignKit — conversion math between the **continuous physical world**
/// (a song, wall-clock seconds) and the **discrete conceptual world**
/// (the PhraseLattice tick grid).
///
/// Extension pack for PhraseLatticeKit. Contains only what is true when
/// nothing is playing: an anchor ("score tick 0 sits at media second X") and
/// the bijection it induces through the tempo map. How the anchor is *found*
/// (evidence, provider quirks) and how playback clocks are *followed* (sync,
/// latency) both live above this kit — no provider names appear here.
let package = Package(
    name: "MediaAlignKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MediaAlign", targets: ["MediaAlign"]),
    ],
    dependencies: [
        .package(path: "../PhraseLatticeKit"),
    ],
    targets: [
        .target(
            name: "MediaAlign",
            dependencies: [
                .product(name: "PhraseLattice", package: "PhraseLatticeKit"),
            ],
            path: "Sources/MediaAlign"
        ),
        .testTarget(
            name: "MediaAlignTests",
            dependencies: ["MediaAlign"],
            path: "Tests/MediaAlignTests"
        ),
    ]
)
