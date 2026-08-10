import MediaAlign
import PhraseLattice
import XCTest

/// Deterministic, clock-free assertions — the kit's whole contract.
final class MediaTimeMapTests: XCTestCase {
    /// 120 BPM → 0.5 s/beat. Anchor: tick 0 at media 1.2 s.
    private var map: MediaTimeMap {
        MediaTimeMap(
            anchor: MediaAnchor(downbeatTimeSeconds: 1.2),
            tempoMap: TempoMap(events: [TempoEvent(tick: 0, bpm: 120)])
        )
    }

    func testTickToMediaSeconds() throws {
        // 2 beats = 48 ticks = 1.0 s after the downbeat → 2.2 s on media.
        XCTAssertEqual(try map.mediaTime(forScoreTick: 48), 2.2, accuracy: 1e-9)
        // Tick 0 lands exactly on the anchor.
        XCTAssertEqual(try map.mediaTime(forScoreTick: 0), 1.2, accuracy: 1e-9)
    }

    func testMediaSecondsToContinuousBeatAndBack() throws {
        let beat = try map.continuousScoreBeat(forMediaTime: 2.2)
        XCTAssertEqual(beat, 2.0, accuracy: 1e-9)
        XCTAssertEqual(try map.mediaTime(forScoreBeatExact: beat), 2.2, accuracy: 1e-9)
    }

    func testMediaBeforeAnchorMapsToNegativeBeats() throws {
        // Media lead (intro before the score) → negative beat, no special case.
        XCTAssertEqual(
            try map.continuousScoreBeat(forMediaTime: 0.7), -1.0, accuracy: 1e-9
        )
    }

    func testNearestTickRounding() throws {
        // 24 PPQ: one tick at 120 BPM ≈ 20.833 ms.
        XCTAssertEqual(try map.scoreTick(forMediaTime: 2.21), 48)
        XCTAssertEqual(try map.scoreTick(forMediaTime: 2.24), 50)
    }

    func testNonFiniteInputsThrow() {
        XCTAssertThrowsError(try map.continuousScoreBeat(forMediaTime: .infinity))
        XCTAssertThrowsError(try map.mediaTime(forScoreBeatExact: .nan))
    }
}
