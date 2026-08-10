import MediaAlign
import PhraseLattice
import XCTest

/// Media capability is opt-in: adopting ScoreMediaLinkedSource makes the
/// decorated projection emit the ordinal-0 offset marker.
private struct SongSketch: ScoreMediaLinkedSource {
    let id = UUID()
    var title = "Song sketch"
    var durationTicks = 8 * 96
    var offsetMs = 1200
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { [] }
    var linkedMedia: ScoreLinkedMedia? {
        ScoreLinkedMedia(
            downbeatOffsetMilliseconds: offsetMs,
            durationMilliseconds: 210_000,
            isInspectable: false
        )
    }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

final class MediaAwareProjectionTests: XCTestCase {
    func testOffsetEmitsLeadInMarker() {
        let spans = ScoreStructureIndex.phraseSpans(in: SongSketch())
        XCTAssertEqual(spans.first?.ordinal, 0)
        XCTAssertEqual(spans.first?.label, "Phrase 0 · Offset")
        XCTAssertEqual(spans.count, 3)  // marker + two 4-bar phrases
    }

    func testNoOffsetMeansNoMarker() {
        var sketch = SongSketch()
        sketch.offsetMs = 0
        let spans = ScoreStructureIndex.phraseSpans(in: sketch)
        XCTAssertNil(spans.first { $0.ordinal == 0 })
        XCTAssertEqual(spans.count, 2)
    }
}
