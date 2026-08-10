import Foundation

// MARK: - Notation vocabulary (phenotype world)

/// Staff letter A–G. The letter alone decides the staff position; accidentals
/// are glyphs layered on top.
public enum PitchLetter: Int, CaseIterable, Sendable, Codable, Equatable, Hashable {
    case c = 0, d, e, f, g, a, b

    /// Semitone offset of the natural letter within an octave (C = 0).
    public var naturalSemitone: Int {
        [0, 2, 4, 5, 7, 9, 11][rawValue]
    }

    public var name: String {
        ["C", "D", "E", "F", "G", "A", "B"][rawValue]
    }
}

/// Accidentals the spelling world allows. **Doubles are excluded by
/// design** — the spelling policy respells across letters instead, so 𝄪/𝄫
/// cannot exist in the phenotype space at the type level.
public enum Accidental: Int, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case flat = -1
    case natural = 0
    case sharp = 1

    /// Compact symbol for labels (`""` for natural; renderers decide when an
    /// explicit ♮ glyph is needed against a key signature).
    public var symbol: String {
        switch self {
        case .flat: return "♭"
        case .natural: return ""
        case .sharp: return "♯"
        }
    }
}

/// A **phenotype**: how a pitch is written, not what it sounds like.
///
/// The genotype is a MIDI-like unique value; one genotype maps to several
/// phenotypes (G♯4 and A♭4 share MIDI 68). The reverse projection
/// ``midi`` is total and lossy; genotype → phenotype is *not* a function —
/// only ``KeySpellingPolicy`` (with a required ``KeySignature`` context)
/// decides it.
public struct SpelledPitch: Sendable, Codable, Equatable, Hashable {
    public var letter: PitchLetter
    public var accidental: Accidental
    /// Scientific octave of the written letter (C4 = MIDI 60).
    public var octave: Int

    public init(letter: PitchLetter, accidental: Accidental = .natural, octave: Int) {
        self.letter = letter
        self.accidental = accidental
        self.octave = octave
    }

    /// The sounding genotype (lossy projection).
    public var midi: Int {
        (octave + 1) * 12 + letter.naturalSemitone + accidental.rawValue
    }

    /// Label such as `"F♯4"`, `"F4"`, `"B♭3"`.
    public var name: String {
        letter.name + accidental.symbol + "\(octave)"
    }
}
