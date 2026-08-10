import StaffLattice
import XCTest

final class KeySpellingPolicyTests: XCTestCase {
    private func name(_ midi: Int, fifths: Int) -> String {
        KeySpellingPolicy.spell(midi: midi, in: KeySignature(fifths: fifths)).name
    }

    func testSharpKeyDiatonicAndCancel() {
        // D major (F♯ C♯): diatonic sharps spell as the signature says…
        XCTAssertEqual(name(66, fifths: 2), "F♯4")
        XCTAssertEqual(name(61, fifths: 2), "C♯4")
        // …and lowering an altered letter cancels with ♮ — never a flat.
        XCTAssertEqual(name(65, fifths: 2), "F4")
        XCTAssertEqual(name(60, fifths: 2), "C4")
    }

    func testFlatKeyDiatonicAndCancel() {
        // E♭ major (B♭ E♭ A♭)
        XCTAssertEqual(name(63, fifths: -3), "E♭4")
        XCTAssertEqual(name(70, fifths: -3), "B♭4")
        // Raising an altered letter cancels with ♮.
        XCTAssertEqual(name(64, fifths: -3), "E4")
        XCTAssertEqual(name(71, fifths: -3), "B4")
    }

    func testChromaticsFollowTheFamily() {
        // C major defaults to sharps.
        XCTAssertEqual(name(66, fifths: 0), "F♯4")
        XCTAssertEqual(name(61, fifths: 0), "C♯4")
        // Flat keys spell chromatics flat: A♭ in F major.
        XCTAssertEqual(name(68, fifths: -1), "A♭4")
        // Sharp keys spell chromatics sharp: G♯ in G major.
        XCTAssertEqual(name(68, fifths: 1), "G♯4")
    }

    func testExtremeSignaturesStaySingleAccidental() {
        // C♯ major (7 sharps): pc 0 is diatonic B♯ — a *single* sharp.
        XCTAssertEqual(name(60, fifths: 7), "B♯3")
        // C♭ major (7 flats): pc 11 is diatonic C♭.
        XCTAssertEqual(name(71, fifths: -7), "C♭5")
    }

    func testGenotypeRoundTripAcrossAllKeys() {
        // The phenotype always projects back to the exact genotype.
        for fifths in -7...7 {
            let signature = KeySignature(fifths: fifths)
            for midi in 21...108 {
                let spelled = KeySpellingPolicy.spell(midi: midi, in: signature)
                XCTAssertEqual(spelled.midi, midi, "\(spelled.name) in fifths \(fifths)")
            }
        }
    }
}
