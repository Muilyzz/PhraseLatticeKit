import Foundation

/// Phrase **fold hinges** on the single PPQ lattice.
///
/// ## Locked product model (Muilyzz / ScoreKit)
///
/// 1. **One long lattice** — PPQ/16th from a single seed (`origin + tempo` = grid width).
/// 2. **Grid width locked** after song link — no casual tempo resize of media spacing.
/// 3. **Initial fold** — opening meter (from AAC/link) groups the whole span into bars.
/// 4. **Phrase breaks** — default 4-bar grid ∪ explicit ``phraseBoundaries`` (bar-snapped).
/// 5. **Meter only at phrase starts** — wrong meter is a **fold** problem (weird last bar /
///    pickup), not lattice misalignment. Pickup is incomplete opening fold, not a second pin.
/// 6. **AAC pin** = evidence / lattice seed marker on media — not a competing tick origin.
///
/// In-memory structure (``ScoreStructureIndex``) and bootstrap factories share this policy
/// so the recursive tree does not depend on UI `barsPerPhrase`.
public enum ScorePhrasePolicy: Sendable {
    /// Default musical phrase length in complete bars.
    public static let defaultBarsPerPhrase = 4

    /// Phrase **start** ticks after the first phrase (tick `0` is always implicit).
    ///
    /// Example: 16 bars of 4/4, `barsPerPhrase == 4` → `[4, 8, 12] × ticksPerBar`.
    /// Exactly 4 bars → `[]` (single phrase; no interior start).
    public static func defaultPhraseStartTicks(
        durationTicks: Int,
        ticksPerBar: Int,
        barsPerPhrase: Int = defaultBarsPerPhrase
    ) -> [ScoreTick] {
        guard durationTicks > 0, ticksPerBar > 0, barsPerPhrase > 0 else { return [] }
        var starts: [ScoreTick] = []
        var barIndex = barsPerPhrase
        while true {
            let (tick, overflow) = barIndex.multipliedReportingOverflow(by: ticksPerBar)
            guard !overflow, tick > 0, tick < durationTicks else { break }
            starts.append(tick)
            let (next, addOverflow) = barIndex.addingReportingOverflow(barsPerPhrase)
            guard !addOverflow else { break }
            barIndex = next
        }
        return starts
    }

    /// ``PhraseBoundary`` list for an empty-boundary document (does not include tick 0).
    public static func defaultPhraseBoundaries(
        durationTicks: Int,
        ticksPerBar: Int,
        barsPerPhrase: Int = defaultBarsPerPhrase
    ) -> [PhraseBoundary] {
        defaultPhraseStartTicks(
            durationTicks: durationTicks,
            ticksPerBar: ticksPerBar,
            barsPerPhrase: barsPerPhrase
        ).map { PhraseBoundary(tick: $0) }
    }

    /// Resolved phrase-start ticks for structure projection **and** meter-change sites.
    ///
    /// Phrase is **not** a list of addable region objects. Projection always:
    /// 1. Lays a default **4-bar** grid over `0..<durationTicks` (grows with duration).
    /// 2. Unions any explicit ``ScoreDocument/phraseBoundaries`` (extra hinges).
    /// 3. Includes implicit start `0`.
    ///
    /// So extending the score (e.g. media cover) never leaves one giant tail phrase;
    /// stale short boundary lists still get a full 4-bar grid on the new length.
    ///
    /// Meter events with `tick > 0` must sit on one of these starts (fold hinge only).
    public static func resolvedPhraseStartTicks(in document: some ScoreStructureSource) -> [ScoreTick] {
        let end = max(document.durationTicks, 0)
        guard end > 0 else { return [] }

        let signature = (try? document.meterMap.signature(at: 0))
            ?? MeterSignature(numerator: 4, denominator: 4)
        let ticksPerBar = max(signature.barDurationTicks, 1)

        var starts = Set(
            defaultPhraseStartTicks(
                durationTicks: end,
                ticksPerBar: ticksPerBar
            )
        )
        let explicit = document.phraseBoundaries.map(\.tick).filter { $0 > 0 && $0 < end }
        starts.formUnion(explicit)
        starts.insert(0)
        return starts.sorted()
    }

    /// `true` when a meter statement may be placed at `tick` (tick 0 or phrase start).
    public static func isPhraseStartTick(_ tick: ScoreTick, in document: some ScoreStructureSource) -> Bool {
        if tick == 0 { return true }
        return resolvedPhraseStartTicks(in: document).contains(tick)
    }

    /// Persistence helper after duration growth: keep user pins in range, ensure 4-bar grid
    /// for the new horizon is stored (so files match what the tree shows).
    public static func phraseBoundariesAfterDurationChange(
        document: some ScoreStructureSource,
        newDurationTicks: Int
    ) -> [PhraseBoundary] {
        let end = max(newDurationTicks, 0)
        guard end > 0 else { return [] }
        let signature = (try? document.meterMap.signature(at: 0))
            ?? MeterSignature(numerator: 4, denominator: 4)
        let ticksPerBar = max(signature.barDurationTicks, 1)
        var ticks = Set(
            defaultPhraseStartTicks(
                durationTicks: end,
                ticksPerBar: ticksPerBar
            )
        )
        // Keep only pins that still land on a bar start under the current meter
        // (e.g. 4/4 pins must not survive a 3/4 re-link).
        for t in document.phraseBoundaries.map(\.tick) where t > 0 && t < end {
            if t % ticksPerBar == 0 {
                ticks.insert(t)
            }
        }
        return ticks.sorted().map { PhraseBoundary(tick: $0) }
    }
}
