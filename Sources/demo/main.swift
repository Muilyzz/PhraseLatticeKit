import Foundation
import PhraseLattice

// `swift run demo` — the README's claims, executing in your terminal.

struct DemoSheet: ScoreStructureSource {
    let id = UUID()
    var title = "Demo"
    /// 16 bars of 4/4 (bar = 4 × 24 ticks = 96).
    var durationTicks = 16 * 96
    var pins: [ScoreTick] = []
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { pins.map { PhraseBoundary(tick: $0) } }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

func show(_ header: String, _ sheet: DemoSheet) {
    print(header)
    for span in ScoreStructureIndex.phraseSpans(in: sheet) {
        let bars = span.range.durationTicks / 96
        print("  \(span.label)  t\(span.range.startTick)…\(span.range.endTick)  (\(bars) bars)")
    }
    print()
}

var sheet = DemoSheet()

// 1. Phrases are a projection — a default 4-bar grid, nothing stored.
show("16 bars of 4/4, no pins — default 4-bar hypermeter grid:", sheet)

// 2. A pin *unions* with the grid; it never replaces it.
sheet.pins = [480]
show("pin at bar 6 (tick 480) — unions with the grid:", sheet)

// 3. Meter changes are only legal at phrase starts (fold hinges).
print("meter change legality:")
print("  tick 480 (hinge)     →", ScorePhrasePolicy.isPhraseStartTick(480, in: sheet))
print("  tick 528 (mid-phrase) →", ScorePhrasePolicy.isPhraseStartTick(528, in: sheet))
print()

// 4. Cursor: arrow keys over the Phrase › Measure › Beat ladder.
print("cursor walk (→ → ↑ ↑):")
var cursor = ScoreStructureCursor.move(from: nil, direction: .right, in: sheet)
print("  entry  →", cursor?.label ?? "nil")
cursor = ScoreStructureCursor.move(from: cursor, direction: .right, in: sheet)
print("  right  →", cursor?.label ?? "nil")
cursor = ScoreStructureCursor.move(from: cursor, direction: .up, in: sheet)
print("  up     →", cursor?.label ?? "nil")
cursor = ScoreStructureCursor.move(from: cursor, direction: .up, in: sheet)
print("  up     →", cursor?.label ?? "nil")
