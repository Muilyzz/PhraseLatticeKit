import Foundation

/// Notation-world key signature: **just the circle-of-fifths index**.
///
/// Deliberately carries no scale semantics — which semitones belong to a
/// scale (tone placement) is a different vocabulary's concern and stays
/// unlinked. Spelling needs only: which letters are altered, and which
/// accidental family the key prefers. A relative major/minor pair shares one
/// value (A minor = C major = `fifths: 0`), which is exactly right for
/// spelling.
public struct KeySignature: Sendable, Codable, Equatable, Hashable {
    /// Circle-of-fifths index, clamped to `-7...7`.
    /// Positive = sharps (G major is `1`), negative = flats (F major is `-1`).
    public let fifths: Int

    public init(fifths: Int) {
        self.fifths = min(7, max(-7, fifths))
    }

    /// Letters altered by this signature, in signature order.
    /// Sharps: F C G D A E B · Flats: B E A D G C F.
    public var alteredLetters: [PitchLetter] {
        let sharpOrder: [PitchLetter] = [.f, .c, .g, .d, .a, .e, .b]
        if fifths >= 0 {
            return Array(sharpOrder.prefix(fifths))
        }
        return Array(sharpOrder.reversed().prefix(-fifths))
    }

    /// The accidental this signature applies to `letter` (`.natural` when
    /// the letter is unaltered).
    public func accidental(for letter: PitchLetter) -> Accidental {
        guard alteredLetters.contains(letter) else { return .natural }
        return fifths > 0 ? .sharp : .flat
    }

    /// Which accidental family chromatic notes prefer in this key.
    public var prefersSharps: Bool { fifths >= 0 }
}
