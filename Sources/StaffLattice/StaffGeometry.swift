import Foundation

/// Staff placement read **directly from the phenotype** — no semitone math.
///
/// A spelled pitch's staff position is decided by its letter and octave
/// alone (G♯4 and A♭4 sit on different lines); the accidental is a glyph,
/// not a position. The diatonic step index makes that literal:
/// `step = letter + 7 × octave`.
public enum StaffGeometry {
    /// Diatonic step index (C0 = 0, one per letter). C4 = 28, E4 = 30.
    public static func step(of pitch: SpelledPitch) -> Int {
        pitch.letter.rawValue + 7 * pitch.octave
    }

    /// Treble staff: bottom line E4 (step 30) … top line F5 (step 38).
    public static let trebleBottomLineStep = 30
    public static let trebleTopLineStep = 38

    /// Steps of the five staff lines (even steps within the staff).
    public static var trebleLineSteps: [Int] {
        stride(from: trebleBottomLineStep, through: trebleTopLineStep, by: 2).map { $0 }
    }

    /// Ledger-line steps a note at `step` requires (even steps outside the
    /// staff, from the staff edge toward the note).
    public static func trebleLedgerSteps(for step: Int) -> [Int] {
        if step < trebleBottomLineStep {
            let first = trebleBottomLineStep - 2
            let lowest = step - (step % 2 == 0 ? 0 : 1)
            return lowest > first ? [] : stride(from: first, through: lowest, by: -2).map { $0 }
        }
        if step > trebleTopLineStep {
            let first = trebleTopLineStep + 2
            let highest = step - (step % 2 == 0 ? 0 : -1)
            return highest < first ? [] : stride(from: first, through: highest, by: 2).map { $0 }
        }
        return []
    }

    /// Standard treble-clef staff steps for signature accidentals,
    /// in signature order (F♯ C♯ G♯ D♯ A♯ E♯ B♯ / B♭ E♭ A♭ D♭ G♭ C♭ F♭).
    public static func trebleSignatureSteps(for signature: KeySignature) -> [Int] {
        let sharpSteps = [38, 35, 39, 36, 33, 37, 34]   // F5 C5 G5 D5 A4 E5 B4
        let flatSteps = [34, 37, 33, 36, 32, 35, 31]    // B4 E5 A4 D5 G4 C5 F4
        if signature.fifths >= 0 {
            return Array(sharpSteps.prefix(signature.fifths))
        }
        return Array(flatSteps.prefix(-signature.fifths))
    }
}
