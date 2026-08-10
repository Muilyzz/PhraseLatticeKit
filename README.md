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

## Media is opt-in, not the base contract

The kit never learns what media *is*. If your score runs parallel to a song,
adopt the refinement and describe the media only by its traits — offset,
extent, and whether its data can be inspected:

```swift
extension MyDocument: ScoreMediaLinkedSource {
    var linkedMedia: ScoreLinkedMedia? {
        ScoreLinkedMedia(
            downbeatOffsetMilliseconds: 1200,   // media starts before the score
            durationMilliseconds: 210_000,
            isInspectable: false                // e.g. a DRM stream
        )
    }
}
```

The projection then additionally emits the ordinal-0 lead-in marker. Time on
the lattice is *conceptual* (what a musician thinks); wall-clock time lives on
the media axis above this kit.

## Contents

| Folder | What |
|---|---|
| `Lattice/` | `ScoreTick` · `ScoreRange` · `ScoreTickGrid` · `MeterMap` · `TempoMap` · `NoteValue` |
| `Phrase/` | `PhraseBoundary` · `SystemBreak` · `ScorePhrasePolicy` |
| `Seam/` | `ScoreStructureSource` (base) · `ScoreMediaLinkedSource` + `ScoreLinkedMedia` (opt-in) |
| `Projection/` | `ScoreStructureIndex` (Score › Phrase › Measure › Beat spans) · logical & geometric cursors |

Tests double as living documentation — see `Tests/PhraseLatticeTests/SeamExampleTests.swift`.
