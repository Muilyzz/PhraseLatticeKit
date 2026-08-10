# MediaAlignKit

**Conversion math between the continuous physical world (a song, seconds) and
the discrete conceptual world (the [PhraseLattice](../PhraseLatticeKit) tick grid).**

Extension pack for PhraseLatticeKit — cores mate with cores: this kit depends
on `PhraseLattice` and nothing else.

```swift
import PhraseLattice
import MediaAlign

let map = MediaTimeMap(
    anchor: MediaAnchor(downbeatTimeSeconds: 1.2),   // "tick 0 lives at 1.2 s"
    tempoMap: TempoMap(events: [TempoEvent(tick: 0, bpm: 120)])
)

try map.mediaTime(forScoreTick: 48)          // 2.2  (2 beats after the anchor)
try map.continuousScoreBeat(forMediaTime: 0.7)   // -1.0 (intro before the score)
try map.scoreTick(forMediaTime: 2.21)        // 48   (nearest lattice point)
```

## What this kit is — and is not

Two litmus tests define the boundary. Logic belongs here only if:

1. **It is true when nothing is playing.** The anchor ("score tick 0 sits at
   media second X") and the bijection it induces through the tempo map are
   facts, not runtime behavior. No clocks, no `Date`, no playback state —
   every function is deterministic.
2. **It needs no provider names.** The kit never learns what the media is.

Everything that fails those tests lives in the layers around it:

| Concern | Where it lives |
|---|---|
| tick ↔ seconds bijection, given an anchor | **this kit** |
| *Finding* the anchor (audio evidence, catalog data) | your app, above |
| Reconciling multiple physical timelines (previews, edits) | your app — reduce to one anchor first |
| Following a playback clock, latency compensation (*sync*) | your player layer |

Fold any source-specific corrections into `downbeatTimeSeconds` **before**
constructing `MediaAnchor` — the kit receives one effective number and asks
no questions.

## Contents

- `MediaAnchor` — the single joining fact, plus the pure ± shift.
- `MediaTimeMap` — anchor + `TempoMap` → strict continuous conversions and
  nearest-tick convenience.

Tests are deterministic assertions on the mapping — see
`Tests/MediaAlignTests/MediaTimeMapTests.swift`.
