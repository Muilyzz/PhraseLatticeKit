// swift-tools-version: 6.0
import PackageDescription

/// PhraseLatticeKit — a **stateless segmentation coordinate system** for scores.
///
/// One module, zero dependencies. Owns the tick lattice (24 PPQ), meter/tempo
/// folds, phrase policy (default 4-bar grid ∪ explicit pins), the structure
/// projection (Score › Phrase › Measure › Beat spans), and cursor navigation.
///
/// Documents stay yours: adopt the seven-member ``ScoreStructureSource``
/// contract and the whole policy → projection → cursor chain works on your
/// type. Linked media is opt-in via ``ScoreMediaLinkedSource``.
let package = Package(
    name: "PhraseLatticeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PhraseLattice", targets: ["PhraseLattice"]),
    ],
    targets: [
        .target(
            name: "PhraseLattice",
            dependencies: [],
            path: "Sources/PhraseLattice"
        ),
        .testTarget(
            name: "PhraseLatticeTests",
            dependencies: ["PhraseLattice"],
            path: "Tests/PhraseLatticeTests"
        ),
    ]
)
