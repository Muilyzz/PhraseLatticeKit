import StaffLattice
import XCTest

final class StaffGeometryTests: XCTestCase {
    func testPhenotypeDecidesTheStep() {
        // G♯4 and A♭4 share a genotype (MIDI 68) but sit on different steps.
        let gSharp = SpelledPitch(letter: .g, accidental: .sharp, octave: 4)
        let aFlat = SpelledPitch(letter: .a, accidental: .flat, octave: 4)
        XCTAssertEqual(gSharp.midi, aFlat.midi)
        XCTAssertEqual(StaffGeometry.step(of: gSharp), 32)
        XCTAssertEqual(StaffGeometry.step(of: aFlat), 33)
    }

    func testTrebleStaffLines() {
        // E4 bottom line … F5 top line.
        XCTAssertEqual(
            StaffGeometry.step(of: SpelledPitch(letter: .e, octave: 4)),
            StaffGeometry.trebleBottomLineStep
        )
        XCTAssertEqual(
            StaffGeometry.step(of: SpelledPitch(letter: .f, octave: 5)),
            StaffGeometry.trebleTopLineStep
        )
        XCTAssertEqual(StaffGeometry.trebleLineSteps.count, 5)
    }

    func testLedgerLines() {
        // Middle C (C4, step 28) needs exactly one ledger line below.
        let c4 = StaffGeometry.step(of: SpelledPitch(letter: .c, octave: 4))
        XCTAssertEqual(StaffGeometry.trebleLedgerSteps(for: c4), [28])
        // D4 (step 29, a space) also shows the C4 ledger line.
        XCTAssertEqual(StaffGeometry.trebleLedgerSteps(for: 29), [28])
        // A5 (step 40) needs one above; notes inside the staff need none.
        XCTAssertEqual(StaffGeometry.trebleLedgerSteps(for: 40), [40])
        XCTAssertEqual(StaffGeometry.trebleLedgerSteps(for: 34), [])
    }

    func testSignatureGlyphPositions() {
        // D major: F♯ on the top line (F5), C♯ in the C5 space.
        XCTAssertEqual(
            StaffGeometry.trebleSignatureSteps(for: KeySignature(fifths: 2)),
            [38, 35]
        )
        // F major: B♭ on the middle line (B4).
        XCTAssertEqual(
            StaffGeometry.trebleSignatureSteps(for: KeySignature(fifths: -1)),
            [34]
        )
    }
}
