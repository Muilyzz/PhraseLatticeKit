import PhraseLattice
import XCTest

/// Living example for the ``ScoreStructureSource`` seam: a host document that
/// knows nothing about harmony (lyrics only) adopts the eight-member contract
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

/// Media is opt-in: a host that links a song adopts the refinement protocol
/// and the projection additionally emits the offset lead-in marker.
private struct SongSketch: ScoreMediaLinkedSource {
    let id = UUID()
    var title = "Song sketch"
    var durationTicks = 8 * 96
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { [] }
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var linkedMedia: ScoreLinkedMedia? {
        ScoreLinkedMedia(
            downbeatOffsetMilliseconds: 1200,
            durationMilliseconds: 210_000,
            isInspectable: false
        )
    }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
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

    func testMediaCapabilityIsOptIn() {
        // Base contract knows nothing about media → no lead-in marker.
        let pure = LyricSheet()
        XCTAssertNil(
            ScoreStructureIndex.phraseSpans(in: pure).first { $0.ordinal == 0 }
        )
        // Adopting ScoreMediaLinkedSource turns the media offset into the
        // ordinal-0 lead-in marker.
        let linked = SongSketch()
        let leadIn = ScoreStructureIndex.phraseSpans(in: linked).first { $0.ordinal == 0 }
        XCTAssertNotNil(leadIn)
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
