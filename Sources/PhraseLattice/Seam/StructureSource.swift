import Foundation

/// The segmentation layer's **position statement** — the minimal read surface
/// that phrase policy, structure projection, and cursor navigation require.
///
/// Layer contract: this kit owns the tick lattice, meter, tempo, and phrase
/// vocabulary. Concepts stacking above (harmony, melody, media, UI) are never
/// referenced here — an upper layer joins by conforming its document type,
/// "requesting" only these seven members. Uniformity is deliberately not a
/// goal; each layer keeps its own vocabulary and adapts at this seam.
/// Linked media is a special case, not part of this base contract — the
/// MediaAlignKit extension pack layers it above.
///
/// Any document model conforms retroactively and reuses the whole
/// policy → projection → cursor chain.
public protocol ScoreStructureSource {
    /// Stable identity used for score-level span IDs.
    var id: UUID { get }
    /// Display title for the score-level span label.
    var title: String { get }
    /// Total lattice length in ticks (tick 0 = first complete bar's downbeat).
    var durationTicks: Int { get }
    /// Pickup (anacrusis) length in ticks before tick 0. `0` when none.
    var pickupTicks: Int { get }
    /// Explicit phrase hinge pins (bar-snapped, unioned with the default grid).
    var phraseBoundaries: [PhraseBoundary] { get }
    /// Meter statements on the lattice (fold information).
    var meterMap: MeterMap { get }
    /// Bar derived from the meter fold at `tick`, `nil` when out of range.
    func bar(containing tick: ScoreTick) throws -> DerivedBar?
}

