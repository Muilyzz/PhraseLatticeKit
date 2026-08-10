import CoreGraphics
import Foundation

// MARK: - Visual anchor (layout-measured cell)

/// One on-screen selectable cell for arrow navigation.
public struct ScoreScopeVisualAnchor: Sendable, Equatable, Hashable {
    public var span: ScoreStructureSpan
    public var frame: CGRect

    public init(span: ScoreStructureSpan, frame: CGRect) {
        self.span = span
        self.frame = frame
    }
}

// MARK: - Geometry cursor (what you see, not scope ladder)

/// Arrow navigation by **screen geometry**.
///
/// Users never think about Phrase/Measure/Beat hierarchy — only the cells
/// in front of them. Phrase measure wrap (1/2/4 per row) is reflected
/// automatically because frames come from the live layout.
///
/// Default keyboard surface is **Beat** cells (finest edit unit). Coarser
/// selections (Measure/Phrase) are mapped into a beat inside them first.
public enum ScoreStructureVisualCursor {
    /// Top-leading beat in visual order (min Y, then min X).
    public static func topLeadingBeat(
        in anchors: [ScoreScopeVisualAnchor]
    ) -> ScoreScopeVisualAnchor? {
        let beats = anchors.filter { $0.span.level == .beat }
        return beats.min { a, b in
            if abs(a.frame.minY - b.frame.minY) > 1 {
                return a.frame.minY < b.frame.minY
            }
            return a.frame.minX < b.frame.minX
        }
    }

    /// Resolve an origin beat for keyboard motion.
    ///
    /// - Beat selection → itself (if framed).
    /// - Measure/Phrase → first framed beat that intersects that range.
    /// - Empty → top-leading beat.
    public static func originBeat(
        selection: ScoreStructureSpan?,
        anchors: [ScoreScopeVisualAnchor]
    ) -> ScoreScopeVisualAnchor? {
        let beats = anchors.filter { $0.span.level == .beat }
        guard !beats.isEmpty else { return nil }

        guard let selection else {
            return topLeadingBeat(in: anchors)
        }

        if selection.level == .beat,
           let match = beats.first(where: { $0.span.id == selection.id }) {
            return match
        }

        // Coarse selection → beat inside it (timeline order among framed beats).
        let inside = beats.filter { beat in
            beat.span.range.intersection(with: selection.range) != nil
        }
        if let first = inside.min(by: { $0.span.range.startTick < $1.span.range.startTick }) {
            return first
        }

        // Stale id — nearest frame to selection start (best effort).
        return beats.min { a, b in
            abs(a.span.range.startTick - selection.range.startTick)
                < abs(b.span.range.startTick - selection.range.startTick)
        }
    }

    /// Next beat in the given visual direction, or `nil` if none.
    public static func move(
        from selection: ScoreStructureSpan?,
        direction: ScoreStructureCursorDirection,
        anchors: [ScoreScopeVisualAnchor]
    ) -> ScoreStructureSpan? {
        let beats = anchors.filter { $0.span.level == .beat }
        guard !beats.isEmpty else { return nil }

        // Empty selection: enter top-leading beat (no step yet).
        if selection == nil {
            return topLeadingBeat(in: anchors)?.span
        }

        guard let origin = originBeat(selection: selection, anchors: anchors) else {
            return topLeadingBeat(in: anchors)?.span
        }

        // If we just mapped Measure/Phrase → beat, land on that beat first
        // when the selection wasn't already that beat (one keypress to enter).
        if let selection, selection.level != .beat, selection.id != origin.span.id {
            return origin.span
        }

        let candidates = beats.map { (id: $0.span.id, frame: $0.frame) }
        guard let nextID = neighbor(
            from: origin.frame,
            direction: direction,
            candidates: candidates
        ) else {
            return origin.span
        }
        return beats.first(where: { $0.span.id == nextID })?.span ?? origin.span
    }

    // MARK: - Neighbor search

    /// Best candidate in `direction` from `origin` (midpoint geometry).
    ///
    /// Primary axis distance + secondary-axis penalty (prefers same row/column
    /// after Phrase wrap). Returns candidate `id`, or `nil` if none qualify.
    public static func neighbor(
        from origin: CGRect,
        direction: ScoreStructureCursorDirection,
        candidates: [(id: String, frame: CGRect)]
    ) -> String? {
        let ox = origin.midX
        let oy = origin.midY
        // Secondary penalty: prefer aligned cells after wrap (same visual row/col).
        let secondaryWeight: CGFloat = 2.5
        let epsilon: CGFloat = 1

        var bestID: String?
        var bestScore = CGFloat.greatestFiniteMagnitude

        for candidate in candidates {
            let frame = candidate.frame
            // Skip self / zero-size
            if frame.width < 0.5 || frame.height < 0.5 { continue }
            if abs(frame.midX - ox) < epsilon && abs(frame.midY - oy) < epsilon {
                continue
            }

            let dx = frame.midX - ox
            let dy = frame.midY - oy
            let primary: CGFloat
            let secondary: CGFloat

            switch direction {
            case .left:
                guard dx < -epsilon else { continue }
                primary = -dx
                secondary = abs(dy)
            case .right:
                guard dx > epsilon else { continue }
                primary = dx
                secondary = abs(dy)
            case .up:
                guard dy < -epsilon else { continue }
                primary = -dy
                secondary = abs(dx)
            case .down:
                guard dy > epsilon else { continue }
                primary = dy
                secondary = abs(dx)
            }

            let score = primary + secondary * secondaryWeight
            if score < bestScore {
                bestScore = score
                bestID = candidate.id
            }
        }
        return bestID
    }
}
