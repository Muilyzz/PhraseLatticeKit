import Foundation

/// Genotype → phenotype translation: a MIDI-like unique value plus the
/// **required** key-signature context decide how a pitch is written.
///
/// Rules, in priority order:
/// 1. **In-signature** — the note is diatonic under the signature: write its
///    letter with the signature's accidental (renderers usually omit the
///    glyph).
/// 2. **Natural cancel** — the accidental works *against* the signature's
///    direction: lowering a sharped letter (or raising a flatted one) is
///    written as that letter with ♮, never as a new ♭/♯.
/// 3. **Family** — other chromatic notes take the signature family's
///    accidental (sharps in sharp keys, flats in flat keys; C major
///    defaults to sharps).
/// 4. Opposite-family fallback (rare).
///
/// Because accidentals only ever push *against* the signature, double
/// accidentals can never accumulate — the output space (`Accidental`)
/// excludes them at the type level.
public enum KeySpellingPolicy {
    public static func spell(midi: Int, in signature: KeySignature) -> SpelledPitch {
        let pitchClass = ((midi % 12) + 12) % 12

        func spelled(_ letter: PitchLetter, _ accidental: Accidental) -> SpelledPitch {
            let octave = (midi - accidental.rawValue - letter.naturalSemitone) / 12 - 1
            return SpelledPitch(letter: letter, accidental: accidental, octave: octave)
        }

        // 1. In-signature (each signature's seven letters cover seven
        //    distinct pitch classes, so a match is unique).
        if let letter = PitchLetter.allCases.first(where: {
            ($0.naturalSemitone + signature.accidental(for: $0).rawValue + 12) % 12 == pitchClass
        }) {
            return spelled(letter, signature.accidental(for: letter))
        }

        // 2. Natural canceling an altered letter.
        if let letter = signature.alteredLetters.first(where: {
            $0.naturalSemitone % 12 == pitchClass
        }) {
            return spelled(letter, .natural)
        }

        // 3. Signature-family accidental.
        let family: Accidental = signature.prefersSharps ? .sharp : .flat
        if let letter = PitchLetter.allCases.first(where: {
            ($0.naturalSemitone + family.rawValue + 12) % 12 == pitchClass
        }) {
            return spelled(letter, family)
        }

        // 4. Opposite family (unreachable in practice, kept total).
        let opposite: Accidental = signature.prefersSharps ? .flat : .sharp
        let letter = PitchLetter.allCases.first(where: {
            ($0.naturalSemitone + opposite.rawValue + 12) % 12 == pitchClass
        })!
        return spelled(letter, opposite)
    }
}
