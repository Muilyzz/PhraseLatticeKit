import Foundation
import PhraseLattice

/// Media-aware decoration of the lattice projection.
///
/// The base projection is purely musical (pickup lead-in only). When the
/// source declares linked media, this overload prepends the synthetic
/// ordinal-0 **offset marker** ("the media runs before the score starts") —
/// the lattice itself stays ignorant of media.
extension ScoreStructureIndex {
    /// Phrase spans with the media lead-in marker when applicable.
    ///
    /// Statically preferred over the base overload for any concrete type
    /// conforming to ``ScoreMediaLinkedSource``.
    public static func phraseSpans(
        in document: some ScoreMediaLinkedSource
    ) -> [ScoreStructureSpan] {
        let base = baseSpans(document)
        // Pickup already produces a musical ordinal-0 span in the base.
        guard max(document.pickupTicks, 0) == 0 else { return base }
        let offsetMs = document.linkedMedia?.downbeatOffsetMilliseconds ?? 0
        guard offsetMs > 0 else { return base }

        // Offset-only: no score ticks before 0 — synthetic empty marker at t0.
        let marker = ScoreStructureSpan(
            id: "phrase.0.leadIn",
            level: .phrase,
            range: ScoreRange(startTick: 0, durationTicks: 0),
            label: "Phrase 0 · Offset",
            ordinal: 0,
            childCount: 0
        )
        return [marker] + base
    }

    /// Routes to the base (media-unaware) overload: the generic parameter is
    /// constrained to `ScoreStructureSource` only, so resolution cannot pick
    /// the media-aware overload again.
    private static func baseSpans<S: ScoreStructureSource>(_ source: S) -> [ScoreStructureSpan] {
        phraseSpans(in: source)
    }
}
