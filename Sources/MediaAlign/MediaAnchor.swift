import Foundation
import PhraseLattice

/// The single fact that joins the two worlds: **score tick 0 sits at media
/// second `downbeatTimeSeconds`**.
///
/// This is the *effective* anchor — hosts fold any source-specific
/// corrections (playback latency, provider timeline quirks) into this one
/// number **before** constructing it. The kit never learns what the media is
/// or how the anchor was found; given the anchor, everything below is pure,
/// clock-free math.
public struct MediaAnchor: Sendable, Codable, Equatable, Hashable {
    /// Media-axis seconds of the score's tick-0 downbeat.
    /// `> 0` when the media begins before the score.
    public var downbeatTimeSeconds: Double

    public init(downbeatTimeSeconds: Double) {
        self.downbeatTimeSeconds = downbeatTimeSeconds
    }

    /// Score-relative seconds for a media timeline time (pure shift).
    public func scoreSeconds(forMediaTime mediaTime: Double) -> Double {
        mediaTime - downbeatTimeSeconds
    }

    /// Media timeline seconds for a score-relative time (pure shift).
    public func mediaTime(forScoreSeconds scoreSeconds: Double) -> Double {
        scoreSeconds + downbeatTimeSeconds
    }
}
