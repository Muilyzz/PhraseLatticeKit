// swift-tools-version: 6.0
import PackageDescription

/// StaffLatticeKit — the **notation (phenotype) world** over the lattice.
///
/// Pitch itself is notation-neutral: a MIDI-like genotype has no opinion
/// about ♭ vs ♯. Determinism appears only when a key signature exists —
/// its preference makes genotype → phenotype a 1:1 translation. This kit
/// owns that phenotype vocabulary (`SpelledPitch`, `KeySignature`,
/// `KeySpellingPolicy`), the staff geometry it induces (letter + octave
/// read directly as a staff step), and a Canvas staff renderer for
/// PhraseLatticeKit's `phraseFooter` lane.
let package = Package(
    name: "StaffLatticeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "StaffLattice", targets: ["StaffLattice"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Muilyzz/PhraseLatticeKit.git", from: "2.8.2"),
    ],
    targets: [
        .target(
            name: "StaffLattice",
            dependencies: [
                .product(name: "PhraseLattice", package: "PhraseLatticeKit"),
                .product(name: "PhraseLatticeUI", package: "PhraseLatticeKit"),
            ],
            path: "Sources/StaffLattice"
        ),
        .testTarget(
            name: "StaffLatticeTests",
            dependencies: ["StaffLattice"],
            path: "Tests/StaffLatticeTests"
        ),
    ]
)
