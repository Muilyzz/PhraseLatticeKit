# StaffLattice

*Module of ScoreLatticeKit — formerly the standalone StaffLatticeKit.*

**The notation (phenotype) world over the lattice — the Y axis.**

Pitch itself is notation-neutral: a MIDI-like genotype has no opinion about
♭ vs ♯. Determinism appears only when a **key signature** exists — its
preference makes genotype → phenotype a 1:1 translation. This module owns
that translation and the staff it induces.

```swift
.product(name: "StaffLattice", package: "ScoreLatticeKit"),
```

## The translation

```swift
import StaffLattice

let dMajor = KeySignature(fifths: 2)                 // F♯ C♯

KeySpellingPolicy.spell(midi: 66, in: dMajor).name   // "F♯4"  (in signature)
KeySpellingPolicy.spell(midi: 65, in: dMajor).name   // "F4"   (♮ cancels — never E♯)
KeySpellingPolicy.spell(midi: 68, in: KeySignature(fifths: -1)).name  // "A♭4"
```

Rules, in priority order: **in-signature** → **natural-cancel** (accidentals
push *against* the signature's direction, so doubles never accumulate —
`Accidental` excludes 𝄪/𝄫 at the type level) → **family**.

`KeySignature` is just the circle-of-fifths index — no scale semantics.
One step on the fifths axis swaps exactly one note of the seven-letter
collection: keep the tonic and you have changed *mode*; move the tonic with
it and you have changed *key*.

## The staff reads the phenotype directly

```swift
StaffGeometry.step(of: SpelledPitch(letter: .g, accidental: .sharp, octave: 4)) // 32
StaffGeometry.step(of: SpelledPitch(letter: .a, accidental: .flat, octave: 4))  // 33
// same genotype (MIDI 68), different staff positions — the letter decides.
```

`step = letter + 7 × octave` — no semitone math. Accidentals are glyphs,
drawn only when they differ from the signature.

## The lane

`StaffLaneView` renders a treble staff in `PhraseLatticeUI`'s
`phraseFooter` slot — **one Canvas per phrase**, no per-note view identity.
Time is lattice-linear (the lane shares the system's endpoints, so notes
align 1:1 with the beats above); pitch placement is phenotype-driven.

```swift
LatticeGridView(source: sheet, selection: $selection) { beat in
    Text(beat.ordinal.map(String.init) ?? "·")
} phraseFooter: { phrase in
    StaffLaneView(phrase: phrase, notes: melody, signature: dMajor)
        .frame(height: 110)
}
```

A dot contour is the *folded* level of detail for the same lane; the staff is
the unfolded one. See `Examples/StaffLaneExample` for the runnable app.

## Family

- [`PhraseLattice`](../Sources/PhraseLattice) — the time axis (this module's only dependency, besides its UI)
- [`MediaAlign`](MediaAlign.md) — continuous ↔ discrete time conversion
- [HarmonyPitch](https://github.com/Muilyzz/HarmonyKit) — the genotype world (notation-neutral by charter), a module of HarmonyKit
