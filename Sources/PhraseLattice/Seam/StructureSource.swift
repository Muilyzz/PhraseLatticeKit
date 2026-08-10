import Foundation

/// The segmentation layer's **position statement** — the minimal read surface
/// that phrase policy, structure projection, and cursor navigation require.
///
/// Layer contract: this kit owns the tick lattice, meter, tempo, and phrase
/// vocabulary. Concepts stacking above (harmony, melody, media, UI) are never
/// referenced here — an upper layer joins by conforming its document type,
/// "requesting" only these seven members. Uniformity is deliberately not a
/// goal; each layer keeps its own vocabulary and adapts at this seam.
/// Linked media is a special case, not part of this base contract — hosts
/// that run parallel media opt in via ``ScoreMediaLinkedSource``.
///
/// `ScoreDocument` conforms retroactively below; a host with a different
/// document model can conform independently and reuse the whole
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

/// Opt-in capability: a source whose score runs **parallel to linked media**.
///
/// Media is a special case, not the base contract — the pure segmentation
/// world never mentions it. A host that links a song adopts this refinement
/// and the projection additionally emits media-driven artifacts (e.g. the
/// offset-only "Phrase 0" lead-in marker).
public protocol ScoreMediaLinkedSource: ScoreStructureSource {
    /// Conceptual parallel media (offset · extent · inspectability), `nil`
    /// when nothing is linked. Identity stays above — see ``ScoreLinkedMedia``.
    var linkedMedia: ScoreLinkedMedia? { get }
}

