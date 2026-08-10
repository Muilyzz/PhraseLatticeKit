import Foundation
import PhraseLattice

/// Conceptual parallel media on the score timeline — **identity unknown**.
///
/// The kit never learns *what* the media is (a file, a DRM stream, a
/// provider, a future format). Only the traits that matter to the lattice:
///
/// - the media may **start at a different point** than score tick 0,
/// - it has **a beginning and an end** (the end may not be known yet),
/// - its data is either **inspectable or not** — can samples be read, or can
///   the host merely play it.
public struct ScoreLinkedMedia: Sendable, Codable, Equatable, Hashable {
    /// Milliseconds from media start to the score's tick-0 downbeat.
    /// `> 0` when the media begins before the score (media lead).
    public var downbeatOffsetMilliseconds: Int

    /// Total media length in milliseconds. The end exists conceptually;
    /// `nil` means it is not known yet (e.g. catalog metadata missing).
    public var durationMilliseconds: Int?

    /// Whether the underlying data can be read (analyzed, waveformed).
    /// `false` for media the host can only play — e.g. a DRM stream.
    public var isInspectable: Bool

    public init(
        downbeatOffsetMilliseconds: Int,
        durationMilliseconds: Int? = nil,
        isInspectable: Bool = false
    ) {
        self.downbeatOffsetMilliseconds = downbeatOffsetMilliseconds
        self.durationMilliseconds = durationMilliseconds
        self.isInspectable = isInspectable
    }
}

/// Opt-in capability: a source whose score runs **parallel to linked media**.
///
/// Media is a special case, not the lattice's base contract — the pure
/// segmentation world never mentions it. A host that links a song adopts this
/// refinement; the media-aware projection below then additionally emits the
/// offset-only "Phrase 0" lead-in marker.
public protocol ScoreMediaLinkedSource: ScoreStructureSource {
    /// Conceptual parallel media, `nil` when nothing is linked.
    var linkedMedia: ScoreLinkedMedia? { get }
}
