# PhraseLatticeKit

**A stateless segmentation coordinate system for musical scores.**

Zero dependencies. One module. Your document stays yours — adopt a
seven-member protocol and reuse the whole policy → projection → cursor chain.

```swift
.package(path: "../PhraseLatticeKit"),          // or the git URL
.product(name: "PhraseLattice", package: "PhraseLatticeKit"),
```

## The idea

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

For the visual version, open `Examples/LatticeGridExample` (project included)
and run it on an iOS simulator — toggle a phrase hinge and watch the grid
re-fold live.

## Rendering: layout is the product, content is injected

The `PhraseLatticeUI` product ships a minimal SwiftUI renderer. The grid draws
phrases › measures › beats and never learns what lives inside a beat — the
slot decides:

```swift
import PhraseLatticeUI

LatticeGridView(source: myDocument, selection: $selection) { beat in
    Text(myContent(for: beat))     // a chord, a lyric, anything
}
```

## Media lives above, not here

This kit is purely the discrete conceptual world. Time on the lattice is what
a musician *thinks*; wall-clock time — a song running parallel to the score —
belongs to the extension pack
**[MediaAlignKit](https://github.com/Muilyzz/MediaAlignKit)**, which layers
the media concept and the continuous ↔ discrete conversion math on top of
this kit's seam.

## Contents

| Where | What |
|---|---|
| `Lattice/` | `ScoreTick` · `ScoreRange` · `ScoreTickGrid` · `MeterMap` · `TempoMap` · `NoteValue` |
| `Phrase/` | `PhraseBoundary` · `SystemBreak` · `ScorePhrasePolicy` |
| `Seam/` | `ScoreStructureSource` — the seven-member host contract |
| `Projection/` | `ScoreStructureIndex` (Score › Phrase › Measure › Beat spans) · logical & geometric cursors |
| `PhraseLatticeUI` | `LatticeGridView` — slot-based SwiftUI grid |

Tests double as living documentation — see `Tests/PhraseLatticeTests/SeamExampleTests.swift`.
