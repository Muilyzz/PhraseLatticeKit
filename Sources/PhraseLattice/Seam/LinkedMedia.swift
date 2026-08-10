import Foundation

/// Conceptual parallel media on the score timeline — **identity unknown**.
///
/// The segmentation layer never learns *what* the media is (a file, a DRM
/// stream, a provider, a future format). It only knows the traits that matter
/// to the lattice:
///
/// - the media may **start at a different point** than score tick 0,
/// - it has **a beginning and an end** (the end may not be known yet),
/// - its data is either **inspectable or not** — can samples be read, or can
///   the host merely play it.
///
/// Concrete media systems (Apple Music, local files, anything else) live in
/// upper layers and reduce themselves to this profile at the
/// ``ScoreStructureSource`` seam.
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
