# MediaAlign

*Module of ScoreLatticeKit — formerly the standalone MediaAlignKit.*

**Conversion math between the continuous physical world (a song, seconds) and
the discrete conceptual world (the [`PhraseLattice`](../Sources/PhraseLattice)
tick grid).**

Cores mate with cores: this module depends on `PhraseLattice` and nothing
else.

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

## What this module is — and is not

Two litmus tests define the boundary. Logic belongs here only if:

1. **It is true when nothing is playing.** The anchor ("score tick 0 sits at
   media second X") and the bijection it induces through the tempo map are
   facts, not runtime behavior. No clocks, no `Date`, no playback state —
   every function is deterministic.
2. **It needs no provider names.** The module never learns what the media is.

Everything that fails those tests lives in the layers around it:

| Concern | Where it lives |
|---|---|
| tick ↔ seconds bijection, given an anchor | **this module** |
| *Finding* the anchor (audio evidence, catalog data) | your app, above |
| Reconciling multiple physical timelines (previews, edits) | your app — reduce to one anchor first |
| Following a playback clock, latency compensation (*sync*) | your player layer |

Fold any source-specific corrections into `downbeatTimeSeconds` **before**
constructing `MediaAnchor` — the module receives one effective number and
asks no questions.

## The media *concept* also lives here

The lattice's base contract never mentions media. If your score runs parallel
to a song, adopt the opt-in refinement and describe the media only by its
traits — offset, extent, inspectability:

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

The decorated projection (`ScoreStructureIndex.phraseSpans` overload from
this module) then prepends the ordinal-0 lead-in marker — the lattice itself
stays media-free.

## State-sync guide (cursor ↔ media position)

The round trip is **not** the identity — seconds → nearest tick → seconds
loses the sub-tick remainder (24 PPQ quantization). Wiring automatic two-way
listeners between the two worlds therefore produces jitter and feedback
loops. The rules that keep it stable:

1. **Convert explicitly, never implicitly.** Every crossing goes through
   `MediaTimeMap`, called at the event site — no `.onChange`-style observers
   that echo one state into the other.
2. **One master per gesture.** While scrubbing, media seconds are the truth
   and the cursor is a derived projection; while navigating, ticks are the
   truth. Derived updates never re-emit events, and are guarded — write only
   when the derived span actually changed.
3. **Two event tiers.** Drag events are auxiliary: light visuals and cheap
   derivations only. The authoritative event fires **once, when the drag
   ends** — that is where a host seeks the player, fetches waveforms, or
   persists.
4. When it grows past two states (e.g. a playback clock joins), promote the
   pair into one reducer — `(state, event) → state` with the map as pure
   math inside — so ownership is decided in a single place.

## Contents

- `ScoreLinkedMedia` / `ScoreMediaLinkedSource` — the media *concept* and the
  opt-in host contract.
- `MediaAnchor` — the single joining fact, plus the pure ± shift.
- `MediaTimeMap` — anchor + `TempoMap` → strict continuous conversions and
  nearest-tick convenience.
- `MediaAwareProjection` — the lead-in decoration over the base projection.

Tests are deterministic assertions on the mapping — see
`Tests/MediaAlignTests/MediaTimeMapTests.swift`.
