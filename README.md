# ScoreLatticeKit

**The score-plane coordinate system — both axes as pure math.**

Zero dependencies. One target per concept. Your document stays yours — adopt
a seven-member protocol and reuse the whole policy → projection → cursor
chain.

|  | physical / raw | policy (the fold) | discrete / notated |
|---|---|---|---|
| **X — time** | media seconds | `TempoMap` · `MeterMap` · `ScorePhrasePolicy` | tick › beat › measure › phrase |
| **Y — pitch** | MIDI genotype | `KeySpellingPolicy` (key signature) | `SpelledPitch` › staff step |

Logical coordinates and folds only — px belongs to the UI layer.

```swift
.package(path: "../ScoreLatticeKit"),                         // or the git URL
.product(name: "ScoreLattice", package: "ScoreLatticeKit"),   // umbrella
// or the narrower leaves: PhraseLattice · MediaAlign · StaffLattice
```

## Modules

| Module | Axis | Owns |
|---|---|---|
| `PhraseLattice` | X | tick lattice (24 PPQ) · meter/tempo folds · phrase policy · structure projection · cursors |
| [`MediaAlign`](Docs/MediaAlign.md) | X | the anchor ("tick 0 sits at media second X") and the bijection it induces |
| [`StaffLattice`](Docs/StaffLattice.md) | Y | genotype → phenotype spelling · staff geometry · staff lane renderers |
| `PhraseLatticeUI` | — | `LatticeGridView` — the slot-based SwiftUI grid |
| `ScoreLattice` | X × Y | umbrella — `@_exported` re-export of the three leaves |

Media and staff are opt-in refinements — the pure lattice never mentions
them. The old repo boundary lives on as a target boundary.

## The idea (X)

Phrases are **not stored objects** — they are a projection:

1. One tick lattice (24 PPQ — the resolution of musical *thought*: 16th = 6,
   32nd = 3, triplet 8th = 8, all integers).
2. A default **4-bar grid** laid over the whole duration (hypermeter prior,
   not a definition — real music overrides it).
3. **Union** with explicit user pins (`PhraseBoundary`, bar-snapped).
4. Tick 0 is always an implicit start.

So every tick belongs to exactly one phrase, nothing goes stale when the
score grows, and meter changes are only legal at phrase starts (fold hinges).
Visual line breaks (`SystemBreak`) are a separate, purely-layout concept —
keeping the musical/visual break distinction explicit is a core design claim.

## The idea (Y)

Pitch itself is notation-neutral: a MIDI-like genotype has no opinion about
♭ vs ♯. Determinism appears only when a **key signature** exists — its
preference makes genotype → phenotype a 1:1 translation, and the staff reads
the phenotype directly (`step = letter + 7 × octave`, no semitone math).
See [Docs/StaffLattice.md](Docs/StaffLattice.md).

## Using it with *your* document

```swift
import PhraseLattice

struct LyricSheet: ScoreStructureSource {          // 7 members, no harmony, no media
    let id = UUID()
    var title = "Sketch"
    var durationTicks = 16 * 96                    // 16 bars of 4/4
    var pins: [ScoreTick] = []
    var meter = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { pins.map { PhraseBoundary(tick: $0) } }
    var meterMap: MeterMap { meter }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meter.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

var sheet = LyricSheet()
ScorePhrasePolicy.resolvedPhraseStartTicks(in: sheet)   // [0, 384, 768, 1152]
sheet.pins = [480]                                       // pin unions, never replaces
ScoreStructureIndex.phraseSpans(in: sheet).count         // 5 phrases
ScoreStructureCursor.move(from: nil, direction: .right, in: sheet)  // arrow-key nav
```

## Try it

```bash
swift run demo
```

prints the whole story — default grid, pin union, meter gating, cursor walk —
in your terminal, no Xcode required.

For the visual versions, open one of the included example projects and run it
on an iOS simulator:

- `Examples/LatticeGridExample` — toggle a phrase hinge, watch the grid re-fold.
- `Examples/MediaBarExample` — per-phrase media strips via the `phraseHeader` slot.
- `Examples/StaffLaneExample` — a grand staff in the `phraseFooter` lane.

## Rendering: layout is the product, content is injected

The `PhraseLatticeUI` product ships a minimal SwiftUI renderer. The grid draws
phrases › measures › beats and never learns what lives inside a beat — the
slot decides:

```swift
import PhraseLatticeUI

LatticeGridView(source: myDocument, selection: $selection) { beat in
    Text(myContent(for: beat))     // a chord, a lyric, anything
} phraseHeader: { phrase in
    MyHeader(phrase)               // optional slot — defaults to a small label
}
```

Grid laws the renderer owns (everything else is a slot):

- **Same time = same width** — every beat gets the same width; a one-bar
  phrase draws narrow instead of stretching.
- **One phrase = one line** — a wrap point reads as a musical signal, so the
  grid never invents one. `beatWidth` is derived from the available width and
  the widest phrase (cells and their computed font shrink instead of
  wrapping); pass an explicit `beatWidth` to opt out.
- **Whitespace is phrase-level only** — time is continuous inside a phrase,
  so measures sit flush: a gap between bars would be a lie. Boundaries are
  carried by barlines, never by spacing.
- **Boundary-weighted barlines** — `BarlineProvider` generates dividers by
  boundary rank (phrase › measure › beat); `DefaultBarlineProvider` draws
  heavier lines for higher boundaries, opening and closing each system.
- **Text law** — cell font size derives from `beatWidth`; content may shrink
  but never truncates ("…") or wraps.
- **Header shares the system's endpoints** — the phrase header is pinned to
  exactly the system row's width. Time density is uniform inside a phrase,
  so time-linear header decorations (media strips, rulers) align 1:1 with
  the beats below.

## PhraseLattice contents

| Where | What |
|---|---|
| `Lattice/` | `ScoreTick` · `ScoreRange` · `ScoreTickGrid` · `MeterMap` · `TempoMap` · `NoteValue` |
| `Phrase/` | `PhraseBoundary` · `SystemBreak` · `ScorePhrasePolicy` |
| `Seam/` | `ScoreStructureSource` — the seven-member host contract |
| `Projection/` | `ScoreStructureIndex` (Score › Phrase › Measure › Beat spans) · logical & geometric cursors |

Tests double as living documentation — see `Tests/PhraseLatticeTests/SeamExampleTests.swift`.

## Lineage

Merged 2026-08-11 from three repos — **PhraseLatticeKit 2.x** (this repo,
renamed), **MediaAlignKit**, **StaffLatticeKit** — histories subtree-merged,
module names unchanged.
