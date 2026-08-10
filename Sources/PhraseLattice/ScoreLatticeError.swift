import Foundation

/// Errors thrown by the lattice vocabulary (tick ranges, tempo/meter maps,
/// bar derivation). Host documents layer their own domain errors above.
public enum ScoreLatticeError: Error, Equatable, Sendable {
    // MARK: Range / arithmetic
    case invalidScoreRange(startTick: ScoreTick, durationTicks: Int)
    case arithmeticOverflow
    case nonFiniteTime(Double)

    // MARK: Tempo map
    case invalidBPM(Double)
    case tempoMapEmpty
    case tempoMapMissingTickZero
    case tempoEventBeforeTickZero(ScoreTick)
    case tempoMapDuplicateTick(ScoreTick)
    case tempoMapUnsorted

    // MARK: Meter map
    case invalidMeterNumerator(Int)
    case invalidMeterDenominator(Int)
    case invalidMeterGrouping(numerator: Int, grouping: [Int])
    case meterMapEmpty
    case meterMapMissingTickZero
    case meterEventBeforeTickZero(ScoreTick)
    case meterMapDuplicateTick(ScoreTick)
    case meterMapUnsorted
    case meterChangeNotOnBarBoundary(tick: ScoreTick, expectedBoundary: ScoreTick)

    // MARK: Pickup / invariants
    case invalidPickupTicks(Int)
    case latticeInvariant(String)
}

extension ScoreLatticeError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidScoreRange(let start, let duration):
            return "ScoreRange(startTick: \(start), durationTicks: \(duration)) must have durationTicks > 0."
        case .arithmeticOverflow:
            return "Score domain arithmetic overflowed Int."
        case .nonFiniteTime(let time):
            return "Time \(time) must be finite."
        case .invalidBPM(let bpm):
            return "BPM \(bpm) must be finite and within 20...400."
        case .tempoMapEmpty:
            return "TempoMap must contain at least one event."
        case .tempoMapMissingTickZero:
            return "TempoMap requires an event effective at tick 0."
        case .tempoEventBeforeTickZero(let tick):
            return "TempoEvent tick \(tick) must be >= 0; the tick-0 tempo applies backward through pickup."
        case .tempoMapDuplicateTick(let tick):
            return "TempoMap has duplicate tick \(tick)."
        case .tempoMapUnsorted:
            return "TempoMap events must be sorted by ascending unique ticks."
        case .invalidMeterNumerator(let n):
            return "Meter numerator \(n) must be > 0."
        case .invalidMeterDenominator(let d):
            return "Meter denominator \(d) must be a power of two in 1...16."
        case .invalidMeterGrouping(let numerator, let grouping):
            return "Meter grouping \(grouping) must be positive integers that sum to \(numerator)."
        case .meterMapEmpty:
            return "MeterMap must contain at least one event."
        case .meterMapMissingTickZero:
            return "MeterMap requires an event at tick 0."
        case .meterEventBeforeTickZero(let tick):
            return "MeterEvent tick \(tick) must be >= 0; the tick-0 meter applies to pickup."
        case .meterMapDuplicateTick(let tick):
            return "MeterMap has duplicate tick \(tick)."
        case .meterMapUnsorted:
            return "MeterMap events must be sorted by ascending unique ticks."
        case .meterChangeNotOnBarBoundary(let tick, let expected):
            return "Meter change at tick \(tick) is not on a bar boundary (nearest valid ≤ target: \(expected))."
        case .invalidPickupTicks(let ticks):
            return "pickupTicks \(ticks) must be >= 0."
        case .latticeInvariant(let message):
            return message
        }
    }
}
