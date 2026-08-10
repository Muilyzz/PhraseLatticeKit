import Foundation

/// A tempo change anchored at an absolute score tick.
public struct TempoEvent: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var tick: ScoreTick
    /// Beats per minute of `beatUnit`. Must be finite and in `20...400`.
    public var bpm: Double
    /// Which written value counts as one beat for `bpm`.
    public var beatUnit: TempoBeatUnit

    public init(
        id: UUID = UUID(),
        tick: ScoreTick,
        bpm: Double,
        beatUnit: TempoBeatUnit = .quarter
    ) {
        self.id = id
        self.tick = tick
        self.bpm = bpm
        self.beatUnit = beatUnit
    }

    public func validate() throws {
        guard bpm.isFinite, bpm >= 20, bpm <= 400 else {
            throw ScoreLatticeError.invalidBPM(bpm)
        }
    }

    /// Seconds per score tick under this tempo.
    public var secondsPerTick: Double {
        // One beatUnit lasts 60/bpm seconds; ticks are quarter-note PPQ.
        (60.0 / bpm) / (beatUnit.quarterNoteMultiplier * Double(ScoreTickGrid.ticksPerBeat))
    }
}

/// Step-tempo map: piecewise-constant BPM between sorted unique event ticks.
///
/// The event at tick 0 is required and also applies backward into negative
/// pickup ticks. Seconds are relative to tick 0 (so tick 0 → 0 seconds).
public struct TempoMap: Sendable, Codable, Equatable, Hashable {
    public var events: [TempoEvent]

    public init(events: [TempoEvent]) {
        self.events = events
    }

    /// Sorted by tick ascending; stable for equal ticks (should not occur after validate).
    public func normalized() -> TempoMap {
        TempoMap(events: events.sorted { $0.tick < $1.tick })
    }

    public func validate() throws {
        guard !events.isEmpty else { throw ScoreLatticeError.tempoMapEmpty }
        for event in events {
            try event.validate()
        }
        if let event = events.first(where: { $0.tick < 0 }) {
            throw ScoreLatticeError.tempoEventBeforeTickZero(event.tick)
        }
        let sorted = events.sorted { $0.tick < $1.tick }
        guard sorted.contains(where: { $0.tick == 0 }) else {
            throw ScoreLatticeError.tempoMapMissingTickZero
        }
        var seen: Set<ScoreTick> = []
        for event in sorted {
            if seen.contains(event.tick) {
                throw ScoreLatticeError.tempoMapDuplicateTick(event.tick)
            }
            seen.insert(event.tick)
        }
        if events.map(\.tick) != sorted.map(\.tick) {
            throw ScoreLatticeError.tempoMapUnsorted
        }
    }

    /// Score-relative seconds at `tick` (tick 0 → 0; negative pickup uses tick-0 tempo).
    public func seconds(at tick: ScoreTick) throws -> Double {
        let map = try prepared()
        if tick == 0 { return 0 }
        if tick < 0 {
            let spt = map.eventEffective(atOrBefore: 0).secondsPerTick
            return Double(tick) * spt
        }
        var total = 0.0
        let sorted = map.events
        for index in sorted.indices {
            let event = sorted[index]
            let segmentStart = max(event.tick, 0)
            let segmentEnd = index + 1 < sorted.count ? sorted[index + 1].tick : tick
            let clampedEnd = min(segmentEnd, tick)
            if clampedEnd > segmentStart {
                total += Double(clampedEnd - segmentStart) * event.secondsPerTick
            }
            if segmentEnd >= tick { break }
        }
        return total
    }

    /// Signed elapsed seconds from `startTick` to `endTick`.
    ///
    /// A reversed interval returns a negative value.
    public func seconds(from startTick: ScoreTick, to endTick: ScoreTick) throws -> Double {
        try seconds(at: endTick) - seconds(at: startTick)
    }

    /// Nearest score tick for score-relative `seconds` (round-trip friendly for values from `seconds(at:)`).
    public func tick(atSeconds seconds: Double) throws -> ScoreTick {
        let exact = try continuousTick(atSeconds: seconds)
        return ScoreTick(exact.rounded())
    }

    /// Continuous (fractional) tick for score-relative `seconds` — no quantize.
    /// Pair with ``seconds(atContinuousTick:)`` for strict media↔score mapping.
    public func continuousTick(atSeconds seconds: Double) throws -> Double {
        let map = try prepared()
        guard seconds.isFinite else {
            throw ScoreLatticeError.nonFiniteTime(seconds)
        }
        if abs(seconds) < 1e-15 { return 0 }
        if seconds < 0 {
            let spt = map.eventEffective(atOrBefore: 0).secondsPerTick
            guard spt > 1e-18 else { return 0 }
            return seconds / spt
        }
        var remaining = seconds
        let sorted = map.events
        for index in sorted.indices {
            let event = sorted[index]
            let segmentStart = max(event.tick, 0)
            let nextTick = index + 1 < sorted.count ? sorted[index + 1].tick : nil
            let spt = event.secondsPerTick
            guard spt > 1e-18 else { continue }
            if let nextTick {
                let segmentTicks = Double(nextTick - segmentStart)
                let segmentSeconds = segmentTicks * spt
                if remaining < segmentSeconds - 1e-15 {
                    return Double(segmentStart) + remaining / spt
                }
                remaining -= segmentSeconds
            } else {
                return Double(segmentStart) + remaining / spt
            }
        }
        let last = sorted[sorted.count - 1]
        let start = max(last.tick, 0)
        let spt = last.secondsPerTick
        guard spt > 1e-18 else { return Double(start) }
        return Double(start) + remaining / spt
    }

    /// Score-relative seconds at a continuous (fractional) tick.
    public func seconds(atContinuousTick tick: Double) throws -> Double {
        guard tick.isFinite else {
            throw ScoreLatticeError.nonFiniteTime(tick)
        }
        if abs(tick) < 1e-15 { return 0 }
        let lo = ScoreTick(floor(tick))
        let hi = ScoreTick(ceil(tick))
        if lo == hi {
            return try seconds(at: lo)
        }
        let s0 = try seconds(at: lo)
        let s1 = try seconds(at: hi)
        let frac = tick - Double(lo)
        return s0 + (s1 - s0) * frac
    }

    private func prepared() throws -> TempoMap {
        let normalized = normalized()
        try normalized.validate()
        return normalized
    }

    fileprivate func eventEffective(atOrBefore tick: ScoreTick) -> TempoEvent {
        // Caller guarantees sorted unique events including tick 0.
        var current = events[0]
        for event in events where event.tick <= tick {
            current = event
        }
        // Negative ticks use the tick-0 event (first event at 0 after normalize).
        if tick < 0 {
            return events.first(where: { $0.tick == 0 }) ?? events[0]
        }
        return current
    }
}
