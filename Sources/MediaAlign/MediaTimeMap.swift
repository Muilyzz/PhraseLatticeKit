import Foundation
import PhraseLattice

/// The bijection between media wall-clock time and lattice coordinates,
/// induced by one ``MediaAnchor`` and the score's ``TempoMap``.
///
/// Deterministic and clock-free: same inputs → same mapping. Nothing here is
/// aware of playback, providers, or how the anchor was discovered.
public struct MediaTimeMap: Sendable, Equatable {
    public var anchor: MediaAnchor
    public var tempoMap: TempoMap

    public init(anchor: MediaAnchor, tempoMap: TempoMap) {
        self.anchor = anchor
        self.tempoMap = tempoMap
    }

    // MARK: Continuous ← → discrete

    /// **Strict** media seconds → continuous score beat (no PPQ quantize).
    /// Every consumer of the same mapping (spectrogram, transport, lattice
    /// overlays) must share this function.
    public func continuousScoreBeat(forMediaTime mediaTime: Double) throws -> Double {
        guard mediaTime.isFinite else {
            throw ScoreLatticeError.nonFiniteTime(mediaTime)
        }
        let scoreSeconds = anchor.scoreSeconds(forMediaTime: mediaTime)
        let continuousTick = try tempoMap.continuousTick(atSeconds: scoreSeconds)
        return continuousTick / Double(max(ScoreTickGrid.ticksPerBeat, 1))
    }

    /// **Strict** continuous score beat → media timeline seconds.
    public func mediaTime(forScoreBeatExact beatExact: Double) throws -> Double {
        guard beatExact.isFinite else {
            throw ScoreLatticeError.nonFiniteTime(beatExact)
        }
        let continuousTick = beatExact * Double(max(ScoreTickGrid.ticksPerBeat, 1))
        let scoreSeconds = try tempoMap.seconds(atContinuousTick: continuousTick)
        let mediaTime = anchor.mediaTime(forScoreSeconds: scoreSeconds)
        guard mediaTime.isFinite else {
            throw ScoreLatticeError.nonFiniteTime(mediaTime)
        }
        return mediaTime
    }

    // MARK: Tick convenience

    /// Absolute score tick → media timeline seconds.
    public func mediaTime(forScoreTick scoreTick: ScoreTick) throws -> Double {
        try mediaTime(
            forScoreBeatExact: Double(scoreTick) / Double(max(ScoreTickGrid.ticksPerBeat, 1))
        )
    }

    /// Media timeline seconds → nearest absolute score tick.
    public func scoreTick(forMediaTime mediaTime: Double) throws -> ScoreTick {
        let beat = try continuousScoreBeat(forMediaTime: mediaTime)
        return ScoreTick((beat * Double(max(ScoreTickGrid.ticksPerBeat, 1))).rounded())
    }
}
