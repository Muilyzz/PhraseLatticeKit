import Foundation

/// Time signature with optional beat grouping (e.g. 6/8 → `[3, 3]`).
public struct MeterSignature: Sendable, Codable, Equatable, Hashable {
    public var numerator: Int
    /// Note value of one beat unit count: power of two in `1...16`.
    public var denominator: Int
    /// Positive integers that sum to `numerator`.
    public var grouping: [Int]

    public init(numerator: Int, denominator: Int, grouping: [Int]? = nil) {
        self.numerator = numerator
        self.denominator = denominator
        self.grouping = grouping ?? MeterSignature.defaultGrouping(numerator: numerator, denominator: denominator)
    }

    /// Sensible default: compound meters with denominator 8 use groups of 3; otherwise one group.
    public static func defaultGrouping(numerator: Int, denominator: Int) -> [Int] {
        if denominator == 8, numerator >= 3, numerator % 3 == 0 {
            return Array(repeating: 3, count: numerator / 3)
        }
        return [numerator]
    }

    /// Ticks of one denominator note at quarter-note PPQ.
    public var beatUnitTicks: Int {
        (ScoreTickGrid.ticksPerBeat * 4) / denominator
    }

    /// Ticks spanning one complete bar.
    public var barDurationTicks: Int {
        numerator * beatUnitTicks
    }

    public func validate() throws {
        guard numerator > 0 else {
            throw ScoreLatticeError.invalidMeterNumerator(numerator)
        }
        guard Self.isValidDenominator(denominator) else {
            throw ScoreLatticeError.invalidMeterDenominator(denominator)
        }
        guard !grouping.isEmpty,
              grouping.allSatisfy({ $0 > 0 }),
              grouping.reduce(0, +) == numerator else {
            throw ScoreLatticeError.invalidMeterGrouping(numerator: numerator, grouping: grouping)
        }
        // beatUnitTicks must divide cleanly (denominator power of two ≤ 16 guarantees this at 24 PPQ).
        guard denominator != 0, (ScoreTickGrid.ticksPerBeat * 4) % denominator == 0 else {
            throw ScoreLatticeError.invalidMeterDenominator(denominator)
        }
    }

    private static func isValidDenominator(_ value: Int) -> Bool {
        let allowed: Set<Int> = [1, 2, 4, 8, 16]
        return allowed.contains(value)
    }
}

/// A meter change anchored at an absolute score tick.
public struct MeterEvent: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var tick: ScoreTick
    public var signature: MeterSignature

    public init(id: UUID = UUID(), tick: ScoreTick, signature: MeterSignature) {
        self.id = id
        self.tick = tick
        self.signature = signature
    }

    public func validate() throws {
        try signature.validate()
    }
}

/// One derived bar segment. Identity is stable via `startTick` (not display ordinal alone).
public struct DerivedBar: Sendable, Codable, Equatable, Hashable {
    public var range: ScoreRange
    public var signature: MeterSignature
    public var isPickup: Bool
    /// Display ordinal: pickup is `0`, first complete bar is `1`, then ascending.
    public var displayOrdinal: Int

    public var startTick: ScoreTick { range.startTick }
    public var endTick: ScoreTick { range.endTick }

    public init(
        range: ScoreRange,
        signature: MeterSignature,
        isPickup: Bool,
        displayOrdinal: Int
    ) {
        self.range = range
        self.signature = signature
        self.isPickup = isPickup
        self.displayOrdinal = displayOrdinal
    }
}

/// Meter map with required tick-0 event; changes only at derived full-bar boundaries.
public struct MeterMap: Sendable, Codable, Equatable, Hashable {
    public var events: [MeterEvent]

    public init(events: [MeterEvent]) {
        self.events = events
    }

    public func normalized() -> MeterMap {
        MeterMap(events: events.sorted { $0.tick < $1.tick })
    }

    public func validate() throws {
        guard !events.isEmpty else { throw ScoreLatticeError.meterMapEmpty }
        for event in events {
            try event.validate()
        }
        if let event = events.first(where: { $0.tick < 0 }) {
            throw ScoreLatticeError.meterEventBeforeTickZero(event.tick)
        }
        let sorted = events.sorted { $0.tick < $1.tick }
        guard sorted.contains(where: { $0.tick == 0 }) else {
            throw ScoreLatticeError.meterMapMissingTickZero
        }
        var seen: Set<ScoreTick> = []
        for event in sorted {
            if seen.contains(event.tick) {
                throw ScoreLatticeError.meterMapDuplicateTick(event.tick)
            }
            seen.insert(event.tick)
        }
        if events.map(\.tick) != sorted.map(\.tick) {
            throw ScoreLatticeError.meterMapUnsorted
        }
        try validateMarkerBoundaries(sorted: sorted)
    }

    /// Ensures each meter change after tick 0 lands on a full-bar boundary.
    public func validateMarkerBoundaries() throws {
        let sorted = events.sorted { $0.tick < $1.tick }
        try validateMarkerBoundaries(sorted: sorted)
    }

    private func validateMarkerBoundaries(sorted: [MeterEvent]) throws {
        if let event = sorted.first(where: { $0.tick < 0 }) {
            throw ScoreLatticeError.meterEventBeforeTickZero(event.tick)
        }
        guard let first = sorted.first, first.tick == 0 else {
            throw ScoreLatticeError.meterMapMissingTickZero
        }
        var cursor = 0
        var signature = first.signature
        try signature.validate()
        for event in sorted.dropFirst() {
            let barLen = signature.barDurationTicks
            guard barLen > 0 else {
                throw ScoreLatticeError.invalidMeterNumerator(signature.numerator)
            }
            var boundary = cursor
            while boundary + barLen <= event.tick {
                boundary += barLen
            }
            guard boundary == event.tick else {
                throw ScoreLatticeError.meterChangeNotOnBarBoundary(
                    tick: event.tick,
                    expectedBoundary: boundary
                )
            }
            cursor = event.tick
            signature = event.signature
            try signature.validate()
        }
    }

    /// Signature of the required tick-0 event. Only valid after `validate()`,
    /// which guarantees the event exists.
    private var tickZeroSignature: MeterSignature {
        events.first { $0.tick == 0 }!.signature
    }

    /// Active signature at `tick` (tick 0 event applies to negative pickup ticks).
    public func signature(at tick: ScoreTick) throws -> MeterSignature {
        let map = try prepared()
        if tick < 0 {
            return map.tickZeroSignature
        }
        var current = map.events[0].signature
        for event in map.events where event.tick <= tick {
            current = event.signature
        }
        return current
    }

    public func bar(containing tick: ScoreTick, pickupTicks: Int) throws -> DerivedBar? {
        try validatePickup(pickupTicks)
        let map = try prepared()
        if pickupTicks > 0, tick >= -pickupTicks, tick < 0 {
            return DerivedBar(
                range: ScoreRange(startTick: -pickupTicks, durationTicks: pickupTicks),
                signature: map.tickZeroSignature,
                isPickup: true,
                displayOrdinal: 0
            )
        }
        if tick < 0 { return nil }
        return try map.enumerateBars(from: 0, through: tick, pickupTicks: pickupTicks)
            .first { $0.range.contains(tick) }
    }

    public func bar(startingAt tick: ScoreTick, pickupTicks: Int) throws -> DerivedBar? {
        try validatePickup(pickupTicks)
        let map = try prepared()
        if pickupTicks > 0, tick == -pickupTicks {
            return DerivedBar(
                range: ScoreRange(startTick: -pickupTicks, durationTicks: pickupTicks),
                signature: map.tickZeroSignature,
                isPickup: true,
                displayOrdinal: 0
            )
        }
        if tick < 0 { return nil }
        return try map.enumerateBars(from: 0, through: tick, pickupTicks: pickupTicks)
            .first { $0.startTick == tick }
    }

    public func bars(intersecting range: ScoreRange, pickupTicks: Int) throws -> [DerivedBar] {
        try range.validate()
        try validatePickup(pickupTicks)
        let map = try prepared()
        let through = max(range.endTick - 1, range.startTick)
        var result = try map.enumerateBars(from: min(0, range.startTick), through: through, pickupTicks: pickupTicks)
        if pickupTicks > 0, range.startTick < 0 {
            let pickup = DerivedBar(
                range: ScoreRange(startTick: -pickupTicks, durationTicks: pickupTicks),
                signature: map.tickZeroSignature,
                isPickup: true,
                displayOrdinal: 0
            )
            if pickup.range.intersection(with: range) != nil,
               !result.contains(where: { $0.startTick == pickup.startTick }) {
                result.insert(pickup, at: 0)
            }
        }
        return result.filter { $0.range.intersection(with: range) != nil }
    }

    private func prepared() throws -> MeterMap {
        let normalized = normalized()
        try normalized.validate()
        return normalized
    }

    private func validatePickup(_ pickupTicks: Int) throws {
        guard pickupTicks >= 0 else {
            throw ScoreLatticeError.invalidPickupTicks(pickupTicks)
        }
    }

    /// Enumerates complete bars from tick 0 through a bar that contains `throughTick`.
    private func enumerateBars(from _: ScoreTick, through throughTick: ScoreTick, pickupTicks: Int) throws -> [DerivedBar] {
        var bars: [DerivedBar] = []
        if pickupTicks > 0 {
            bars.append(
                DerivedBar(
                    range: ScoreRange(startTick: -pickupTicks, durationTicks: pickupTicks),
                    signature: tickZeroSignature,
                    isPickup: true,
                    displayOrdinal: 0
                )
            )
        }
        guard throughTick >= 0 else { return bars }

        var cursor = 0
        var ordinal = 1
        var eventIndex = 0
        // Safety cap: avoid runaway if invariants break.
        let maxBars = 1_000_000
        var count = 0
        while cursor <= throughTick {
            while eventIndex + 1 < events.count, events[eventIndex + 1].tick <= cursor {
                eventIndex += 1
            }
            let signature = events[eventIndex].signature
            let barLen = signature.barDurationTicks
            guard barLen > 0 else {
                throw ScoreLatticeError.invalidMeterNumerator(signature.numerator)
            }
            let range = ScoreRange(startTick: cursor, durationTicks: barLen)
            bars.append(
                DerivedBar(
                    range: range,
                    signature: signature,
                    isPickup: false,
                    displayOrdinal: ordinal
                )
            )
            if range.contains(throughTick) { break }
            cursor += barLen
            ordinal += 1
            count += 1
            if count > maxBars {
                throw ScoreLatticeError.latticeInvariant("Derived bar enumeration exceeded safety limit.")
            }
        }
        return bars
    }
}
