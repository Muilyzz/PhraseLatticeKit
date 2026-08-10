import PhraseLattice
import XCTest

/// Living example for the ``ScoreStructureSource`` seam: a host document that
/// knows nothing about harmony (lyrics only) adopts the seven-member contract
/// and reuses the whole policy → projection → cursor chain.
private struct LyricSheet {
    let id = UUID()
    var title = "Sketch"
    var lyrics: [String] = []
    /// 16 bars of 4/4 (bar = 4 × 24 ticks = 96).
    var durationTicks = 16 * 96
    /// User-pinned phrase hinges.
    var pins: [ScoreTick] = []
    var meter = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
}

extension LyricSheet: ScoreStructureSource {
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { pins.map { PhraseBoundary(tick: $0) } }
    var meterMap: MeterMap { meter }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meter.bar(containing: tick, pickupTicks: pickupTicks)
    }
}


final class ScoreStructureSourceSeamTests: XCTestCase {
    func testForeignDocumentGetsDefaultFourBarProjection() {
        let sheet = LyricSheet(lyrics: ["first line", "second line"])
        // Default 4-bar grid over 16 bars — pure projection, nothing stored.
        XCTAssertEqual(
            ScorePhrasePolicy.resolvedPhraseStartTicks(in: sheet),
            [0, 384, 768, 1152]
        )
    }

    func testPinUnionsWithDefaultGridAndGatesMeter() {
        var sheet = LyricSheet()
        // Bar 6 start (tick 480) is not a hinge yet → meter change refused there.
        XCTAssertFalse(ScorePhrasePolicy.isPhraseStartTick(480, in: sheet))
        sheet.pins = [480]
        // Pin unions with the 4-bar grid instead of replacing it.
        XCTAssertTrue(ScorePhrasePolicy.isPhraseStartTick(480, in: sheet))
        XCTAssertEqual(
            ScorePhrasePolicy.resolvedPhraseStartTicks(in: sheet),
            [0, 384, 480, 768, 1152]
        )
        XCTAssertEqual(ScoreStructureIndex.phraseSpans(in: sheet).count, 5)
    }



    func testCursorNavigatesForeignDocument() {
        let sheet = LyricSheet()
        let entry = ScoreStructureCursor.move(from: nil, direction: .right, in: sheet)
        XCTAssertEqual(entry?.level, .beat)
        let measure = ScoreStructureCursor.move(from: entry, direction: .up, in: sheet)
        XCTAssertEqual(measure?.level, .measure)
        let phrase = ScoreStructureCursor.move(from: measure, direction: .up, in: sheet)
        XCTAssertEqual(phrase?.level, .phrase)
    }
}
