import Foundation

// MARK: - Cursor direction

/// Arrow-key movement on the Phrase › Measure › Beat ladder.
public enum ScoreStructureCursorDirection: String, Sendable, Equatable, Hashable, CaseIterable {
    case left
    case right
    case up
    case down
}

// MARK: - Pure navigation

/// Editor-style cursor for scope selection (no UI).
///
/// | Key | Same-level | Hierarchy |
/// |-----|------------|-----------|
/// | ← / → | previous / next span of **same level** (timeline order) | — |
/// | ↑ | — | parent (Beat→Measure→Phrase) |
/// | ↓ | — | first child (Phrase→Measure→Beat) |
///
/// Empty selection + any arrow → first Beat (or coarsest available unit).
public enum ScoreStructureCursor {
    /// Move selection one step, or enter the tree when nothing is selected.
    public static func move(
        from selection: ScoreStructureSpan?,
        direction: ScoreStructureCursorDirection,
        in document: some ScoreStructureSource
    ) -> ScoreStructureSpan? {
        if let selection, isSelectable(selection) {
            return step(from: selection, direction: direction, in: document) ?? selection
        }
        return defaultEntry(in: document)
    }

    /// Preferred entry when nothing is selected: first Beat, else Measure, else Phrase.
    public static func defaultEntry(in document: some ScoreStructureSource) -> ScoreStructureSpan? {
        let beats = allSpans(at: .beat, in: document)
        if let first = beats.first { return first }
        let measures = allSpans(at: .measure, in: document)
        if let first = measures.first { return first }
        return allSpans(at: .phrase, in: document).first
    }

    public static func isSelectable(_ span: ScoreStructureSpan) -> Bool {
        switch span.level {
        case .phrase, .measure, .beat: return true
        case .score: return false
        }
    }

    // MARK: - Step

    private static func step(
        from selection: ScoreStructureSpan,
        direction: ScoreStructureCursorDirection,
        in document: some ScoreStructureSource
    ) -> ScoreStructureSpan? {
        switch direction {
        case .left:
            return neighbor(of: selection, delta: -1, in: document)
        case .right:
            return neighbor(of: selection, delta: 1, in: document)
        case .up:
            return parent(of: selection, in: document)
        case .down:
            return firstChild(of: selection, in: document)
        }
    }

    /// Same-level neighbor in global timeline order (crosses phrase/measure edges).
    private static func neighbor(
        of selection: ScoreStructureSpan,
        delta: Int,
        in document: some ScoreStructureSource
    ) -> ScoreStructureSpan? {
        let peers = allSpans(at: selection.level, in: document)
        guard let index = peers.firstIndex(where: { $0.id == selection.id }) else {
            // Stale selection after structure change — snap to nearest by start tick.
            return nearest(to: selection.range.startTick, in: peers)
        }
        let next = index + delta
        guard peers.indices.contains(next) else { return nil }
        return peers[next]
    }

    private static func parent(
        of selection: ScoreStructureSpan,
        in document: some ScoreStructureSource
    ) -> ScoreStructureSpan? {
        switch selection.level {
        case .beat:
            return enclosing(level: .measure, tick: selection.range.startTick, in: document)
        case .measure:
            return enclosing(level: .phrase, tick: selection.range.startTick, in: document)
        case .phrase, .score:
            return nil
        }
    }

    private static func firstChild(
        of selection: ScoreStructureSpan,
        in document: some ScoreStructureSource
    ) -> ScoreStructureSpan? {
        ScoreStructureIndex.children(of: selection, in: document).first
    }

    private static func enclosing(
        level: ScoreStructureLevel,
        tick: ScoreTick,
        in document: some ScoreStructureSource
    ) -> ScoreStructureSpan? {
        allSpans(at: level, in: document).first { $0.range.contains(tick) }
    }

    private static func nearest(
        to tick: ScoreTick,
        in spans: [ScoreStructureSpan]
    ) -> ScoreStructureSpan? {
        spans.min { a, b in
            abs(a.range.startTick - tick) < abs(b.range.startTick - tick)
        }
    }

    // MARK: - Flatten

    /// All spans of `level` in left-to-right / top-to-bottom score order.
    public static func allSpans(
        at level: ScoreStructureLevel,
        in document: some ScoreStructureSource
    ) -> [ScoreStructureSpan] {
        switch level {
        case .score:
            return [ScoreStructureIndex.scoreSpan(in: document)]
        case .phrase:
            return ScoreStructureIndex.phraseSpans(in: document)
        case .measure:
            return ScoreStructureIndex.phraseSpans(in: document).flatMap { phrase in
                ScoreStructureIndex.children(of: phrase, in: document)
            }
        case .beat:
            return ScoreStructureIndex.phraseSpans(in: document).flatMap { phrase in
                ScoreStructureIndex.children(of: phrase, in: document).flatMap { measure in
                    ScoreStructureIndex.children(of: measure, in: document)
                }
            }
        }
    }
}
