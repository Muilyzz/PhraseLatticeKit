import Foundation

/// The single PPQ lattice constant — ScoreCore owns its tick resolution.
///
/// Mirrors `HarmonicsKit.RhythmGrid.ticksPerBeat` by value (drift-guarded in
/// ScoreKitTests) but carries no dependency: segmentation vocabulary is
/// self-contained; harmony layers stack on top via ``ScoreStructureSource``.
public enum ScoreTickGrid {
    /// 24 ticks/beat: 16th=6, 32nd=3, triplet 8th=8 — all integers.
    public static let ticksPerBeat = 24
}

/// Absolute score coordinate in quarter-note PPQ ticks (`ScoreTickGrid.ticksPerBeat`).
///
/// Tick 0 is the first complete bar's downbeat. Negative ticks represent pickup
/// (anacrusis) before that downbeat.
public typealias ScoreTick = Int

/// Half-open tick interval `[startTick, endTick)`.
public struct ScoreRange: Sendable, Codable, Equatable, Hashable {
    public var startTick: ScoreTick
    /// Length in ticks; must be strictly positive for a valid range.
    public var durationTicks: Int

    public init(startTick: ScoreTick, durationTicks: Int) {
        self.startTick = startTick
        self.durationTicks = durationTicks
    }

    /// Exclusive end tick (`startTick + durationTicks`).
    public var endTick: ScoreTick { startTick + durationTicks }

    /// Half-open containment: `startTick <= tick < endTick`.
    public func contains(_ tick: ScoreTick) -> Bool {
        tick >= startTick && tick < endTick
    }

    /// Intersection of two half-open ranges, or `nil` if empty / invalid inputs.
    public func intersection(with other: ScoreRange) -> ScoreRange? {
        guard durationTicks > 0, other.durationTicks > 0 else { return nil }
        let start = max(startTick, other.startTick)
        let end = min(endTick, other.endTick)
        let duration = end - start
        guard duration > 0 else { return nil }
        return ScoreRange(startTick: start, durationTicks: duration)
    }

    /// Validates positive duration and no arithmetic overflow on `endTick`.
    public func validate() throws {
        guard durationTicks > 0 else {
            throw ScoreLatticeError.invalidScoreRange(startTick: startTick, durationTicks: durationTicks)
        }
        let (end, overflow) = startTick.addingReportingOverflow(durationTicks)
        guard !overflow else {
            throw ScoreLatticeError.arithmeticOverflow
        }
        _ = end
    }
}
