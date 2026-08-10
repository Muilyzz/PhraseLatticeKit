// swift-tools-version: 6.0
import PackageDescription

/// ScoreLatticeKit — the **score-plane coordinate system**, both axes as
/// pure math.
///
/// X is time: the tick lattice (24 PPQ), meter/tempo folds, phrase policy,
/// the structure projection and cursors (`PhraseLattice`), plus the anchor
/// bijection to parallel-media seconds (`MediaAlign`). Y is pitch: the
/// genotype → phenotype spelling fold and the staff geometry it induces
/// (`StaffLattice`). Logical coordinates and folds only — px stays in UI.
///
/// One target per concept; the `ScoreLattice` umbrella re-exports the plane.
/// Documents stay yours: adopt the seven-member ``ScoreStructureSource``
/// contract and the whole chain works on your type. Media and staff are
/// opt-in refinements — the pure lattice never mentions them.
let package = Package(
    name: "ScoreLatticeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Umbrella — the whole plane in one import.
        .library(name: "ScoreLattice", targets: ["ScoreLattice"]),
        // Leaves — one per concept.
        .library(name: "PhraseLattice", targets: ["PhraseLattice"]),
        .library(name: "MediaAlign", targets: ["MediaAlign"]),
        .library(name: "StaffLattice", targets: ["StaffLattice"]),
        // App-flavored extra (slot-based SwiftUI grid renderer).
        .library(name: "PhraseLatticeUI", targets: ["PhraseLatticeUI"]),
    ],
    targets: [
        .target(name: "PhraseLattice"),
        .target(name: "MediaAlign", dependencies: ["PhraseLattice"]),
        .target(
            name: "StaffLattice",
            dependencies: ["PhraseLattice", "PhraseLatticeUI"]
        ),
        .target(name: "PhraseLatticeUI", dependencies: ["PhraseLattice"]),
        .target(
            name: "ScoreLattice",
            dependencies: ["PhraseLattice", "MediaAlign", "StaffLattice"]
        ),
        .executableTarget(name: "demo", dependencies: ["PhraseLattice"]),
        .testTarget(name: "PhraseLatticeTests", dependencies: ["PhraseLattice"]),
        .testTarget(name: "MediaAlignTests", dependencies: ["MediaAlign"]),
        .testTarget(name: "StaffLatticeTests", dependencies: ["StaffLattice"]),
    ]
)
