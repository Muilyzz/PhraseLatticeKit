import Foundation

/// Hierarchy used by the structure drill UI. Same shell for every level.
public enum ScoreStructureLevel: String, Sendable, Equatable, Hashable, CaseIterable, Codable {
    case score
    case phrase
    case measure
    case beat

    public var title: String {
        switch self {
        case .score: return "Score"
        case .phrase: return "Phrase"
        case .measure: return "Measure"
        case .beat: return "Beat"
        }
    }

    /// Next finer level when drilling in (nil at leaf).
    public var childLevel: ScoreStructureLevel? {
        switch self {
        case .score: return .phrase
        case .phrase: return .measure
        case .measure: return .beat
        case .beat: return nil
        }
    }
}

// MARK: - Span (one row in the drill list)

/// One contiguous region on the score timeline.
///
/// Uniform record — kind/level differs, list/drill UI stays the same.
public struct ScoreStructureSpan: Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var level: ScoreStructureLevel
    /// Inclusive start … exclusive end on the complete-bar timeline when possible.
    public var range: ScoreRange
    public var label: String
    /// Display ordinal (1-based) within parent, when meaningful.
    public var ordinal: Int?
    public var childCount: Int

    public init(
        id: String,
        level: ScoreStructureLevel,
        range: ScoreRange,
        label: String,
        ordinal: Int? = nil,
        childCount: Int = 0
    ) {
        self.id = id
        self.level = level
        self.range = range
        self.label = label
        self.ordinal = ordinal
        self.childCount = childCount
    }

    public var tickSummary: String {
        "t\(range.startTick)…\(range.endTick)"
    }
}

// MARK: - Index (pure projection from ScoreDocument)

/// Builds Score → Phrase → Measure → Beat spans without UI.
public enum ScoreStructureIndex {
    /// Song root span covering the complete-bar timeline `0..<durationTicks`.
    public static func scoreSpan(in document: some ScoreStructureSource) -> ScoreStructureSpan {
        let phrases = phraseSpans(in: document)
        let range = ScoreRange(startTick: 0, durationTicks: max(document.durationTicks, 0))
        return ScoreStructureSpan(
            id: "score.\(document.id.uuidString)",
            level: .score,
            range: range,
            label: document.title.isEmpty ? "Untitled score" : document.title,
            ordinal: nil,
            childCount: phrases.count
        )
    }

    /// Phrase regions for the recursive tree / structure UI.
    ///
    /// Rules (see ``ScorePhrasePolicy/resolvedPhraseStartTicks``):
    /// - Always a default **4-bar** grid over the current duration.
    /// - Explicit ``phraseBoundaries`` pins add extra breaks (union, not replace).
    /// - Each phrase runs until the next start (or `durationTicks`).
    ///
    /// Projection only — does not mutate the document.
    public static func phraseSpans(in document: some ScoreStructureSource) -> [ScoreStructureSpan] {
        let end = max(document.durationTicks, 0)
        guard end > 0 else { return [] }

        let sorted = ScorePhrasePolicy.resolvedPhraseStartTicks(in: document)

        var spans: [ScoreStructureSpan] = []

        // Phrase **0** — exceptional lead-in (musical pickup and/or media offset before t0).
        if let leadIn = leadInPhraseSpan(in: document) {
            spans.append(leadIn)
        }

        for (index, start) in sorted.enumerated() {
            let next = index + 1 < sorted.count ? sorted[index + 1] : end
            let duration = max(next - start, 0)
            guard duration > 0 else { continue }
            // Complete phrases stay 1-based (first on-grid phrase is 1).
            let ordinal = index + 1
            let range = ScoreRange(startTick: start, durationTicks: duration)
            let childCount = (try? measureCount(in: range, document: document)) ?? 0
            spans.append(
                ScoreStructureSpan(
                    id: "phrase.\(ordinal).\(start)",
                    level: .phrase,
                    range: range,
                    label: "Phrase \(ordinal)",
                    ordinal: ordinal,
                    childCount: childCount
                )
            )
        }
        return spans
    }

    /// Lead-in span at ordinal 0 when pickup ticks or media downbeat offset exist.
    private static func leadInPhraseSpan(in document: some ScoreStructureSource) -> ScoreStructureSpan? {
        let pickup = max(document.pickupTicks, 0)
        // Media is opt-in: only sources that declare the capability get the
        // offset-only lead-in marker.
        let offsetMs = (document as? any ScoreMediaLinkedSource)?
            .linkedMedia?.downbeatOffsetMilliseconds ?? 0
        guard pickup > 0 || offsetMs > 0 else { return nil }

        let startTick: ScoreTick
        let durationTicks: Int
        let label: String
        if pickup > 0 {
            startTick = -pickup
            durationTicks = pickup
            label = "Phrase 0 · Pickup"
        } else {
            // Offset-only: no score ticks before 0 — synthetic empty lead-in marker at t0.
            startTick = 0
            durationTicks = 0
            label = "Phrase 0 · Offset"
        }

        let range = ScoreRange(startTick: startTick, durationTicks: max(durationTicks, 0))
        return ScoreStructureSpan(
            id: "phrase.0.leadIn",
            level: .phrase,
            range: range,
            label: label,
            ordinal: 0,
            childCount: pickup > 0 ? 1 : 0
        )
    }

    /// Children of a span for drill-in.
    public static func children(
        of span: ScoreStructureSpan,
        in document: some ScoreStructureSource
    ) -> [ScoreStructureSpan] {
        switch span.level {
        case .score:
            return phraseSpans(in: document)
        case .phrase:
            return measureSpans(in: span.range, document: document, parentID: span.id)
        case .measure:
            return beatSpans(in: span.range, document: document, parentID: span.id)
        case .beat:
            return []
        }
    }

    // MARK: - Phrase boundary edits (pure)

    /// Insert a phrase start at `tick` (clamped into the complete-bar timeline).
    public static func insertingPhraseBoundary(
        _ tick: ScoreTick,
        in document: some ScoreStructureSource
    ) -> [ScoreTick] {
        let end = max(document.durationTicks, 0)
        guard end > 0 else { return document.phraseBoundaries.map(\.tick) }
        let t = min(max(tick, 0), end - 1)
        var ticks = Set(document.phraseBoundaries.map(\.tick).filter { $0 >= 0 && $0 < end })
        ticks.insert(0)
        ticks.insert(t)
        return ticks.sorted()
    }

    /// Remove a phrase start (cannot remove the implicit `0` if it is the only start).
    public static func removingPhraseBoundary(
        _ tick: ScoreTick,
        in document: some ScoreStructureSource
    ) -> [ScoreTick] {
        let end = max(document.durationTicks, 0)
        var ticks = Set(document.phraseBoundaries.map(\.tick).filter { $0 >= 0 && $0 < end })
        ticks.remove(tick)
        // Keep at least one phrase covering the score (implicit 0).
        if ticks.isEmpty || !ticks.contains(0) && ticks.min() != 0 {
            ticks.insert(0)
        }
        // Do not store redundant sole-0 unless user had other boundaries.
        if ticks == [0], document.phraseBoundaries.isEmpty {
            return []
        }
        if ticks == [0] {
            // Explicit empty list means one default phrase.
            return []
        }
        return ticks.sorted()
    }

    // MARK: - Measures (for childCount + next drill step)

    /// Measure spans overlapping `range` (complete bars from the meter map).
    public static func measureSpans(
        in range: ScoreRange,
        document: some ScoreStructureSource,
        parentID: String
    ) -> [ScoreStructureSpan] {
        guard range.durationTicks > 0 else { return [] }
        var spans: [ScoreStructureSpan] = []
        var tick = max(range.startTick, 0)
        let end = min(range.endTick, max(document.durationTicks, 0))
        var ordinal = 1
        while tick < end {
            guard let bar = try? document.bar(containing: tick), !bar.isPickup else {
                // Skip pickup / holes by advancing one beat unit.
                tick += max(ScoreTickGrid.ticksPerBeat, 1)
                continue
            }
            let barStart = bar.startTick
            let barEnd = bar.startTick + bar.signature.barDurationTicks
            let clippedStart = max(barStart, range.startTick)
            let clippedEnd = min(barEnd, end)
            let duration = clippedEnd - clippedStart
            if duration > 0 {
                let measureRange = ScoreRange(startTick: clippedStart, durationTicks: duration)
                let beatCount = beatSpans(
                    in: measureRange,
                    document: document,
                    parentID: "\(parentID).m\(ordinal)"
                ).count
                spans.append(
                    ScoreStructureSpan(
                        id: "\(parentID).m\(ordinal).\(clippedStart)",
                        level: .measure,
                        range: measureRange,
                        label: "Measure \(bar.displayOrdinal)",
                        ordinal: ordinal,
                        childCount: beatCount
                    )
                )
                ordinal += 1
            }
            let next = barEnd
            if next <= tick { break }
            tick = next
        }
        return spans
    }

    /// Beat spans inside a measure (meter beat units from the containing bar).
    public static func beatSpans(
        in range: ScoreRange,
        document: some ScoreStructureSource,
        parentID: String
    ) -> [ScoreStructureSpan] {
        guard range.durationTicks > 0 else { return [] }
        let unit: Int = {
            if let bar = try? document.bar(containing: range.startTick) {
                return max(bar.signature.beatUnitTicks, 1)
            }
            return max(ScoreTickGrid.ticksPerBeat, 1)
        }()

        var spans: [ScoreStructureSpan] = []
        var tick = range.startTick
        var ordinal = 1
        while tick < range.endTick {
            let next = min(tick + unit, range.endTick)
            let duration = next - tick
            if duration > 0 {
                spans.append(
                    ScoreStructureSpan(
                        id: "\(parentID).b\(ordinal).\(tick)",
                        level: .beat,
                        range: ScoreRange(startTick: tick, durationTicks: duration),
                        label: "Beat \(ordinal)",
                        ordinal: ordinal,
                        childCount: 0
                    )
                )
                ordinal += 1
            }
            if next <= tick { break }
            tick = next
        }
        return spans
    }

    private static func measureCount(
        in range: ScoreRange,
        document: some ScoreStructureSource
    ) throws -> Int {
        measureSpans(in: range, document: document, parentID: "tmp").count
    }
}
