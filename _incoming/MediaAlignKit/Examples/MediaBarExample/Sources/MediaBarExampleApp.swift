import MediaAlign
import PhraseLattice
import PhraseLatticeUI
import SwiftUI

/// Composition the base kit never anticipated: a **media bar** (continuous
/// world, seconds) docked above the **lattice grid** (discrete world, ticks),
/// joined by `MediaTimeMap`. Scrub the bar — the beat selection follows.
struct SongSheet: ScoreMediaLinkedSource {
    let id = UUID()
    var title = "Media bar example"
    /// 8 bars of 4/4 at 120 BPM → 16 s of score.
    var durationTicks = 8 * 96
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var tempoMap = TempoMap(events: [TempoEvent(tick: 0, bpm: 120)])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { [] }
    /// The song: 20 s long, score downbeat lands at 1.2 s (media lead).
    var linkedMedia: ScoreLinkedMedia? {
        ScoreLinkedMedia(
            downbeatOffsetMilliseconds: 1200,
            durationMilliseconds: 20_000,
            isInspectable: false
        )
    }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

@main
struct MediaBarExampleApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    private let sheet = SongSheet()
    @State private var mediaSeconds: Double = 0
    @State private var committedSeconds: Double?
    @State private var selection: ScoreStructureSpan?

    private var mediaDuration: Double {
        Double(sheet.linkedMedia?.durationMilliseconds ?? 0) / 1000
    }

    private var timeMap: MediaTimeMap {
        MediaTimeMap(
            anchor: MediaAnchor(
                downbeatTimeSeconds: Double(sheet.linkedMedia?.downbeatOffsetMilliseconds ?? 0) / 1000
            ),
            tempoMap: sheet.tempoMap
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                MediaBar(
                    timeMap: timeMap,
                    mediaDuration: mediaDuration,
                    scoreEndTick: sheet.durationTicks,
                    mediaSeconds: $mediaSeconds
                ) { seconds in
                    // Scrub tier — light preview only. Continuous → discrete
                    // through the map, with a change guard so derived state
                    // is written only when the beat actually changes.
                    guard
                        let tick = try? timeMap.scoreTick(forMediaTime: seconds),
                        let beat = ScoreStructureCursor
                            .allSpans(at: .beat, in: sheet)
                            .first(where: { $0.range.contains(tick) }),
                        selection?.id != beat.id
                    else { return }
                    selection = beat
                } onCommit: { seconds in
                    // Commit tier — the authoritative event, fired once when
                    // the drag ends. A real host runs the heavy work here:
                    // player.seek, waveform fetch, persistence.
                    committedSeconds = seconds
                }
                .frame(height: 44)

                Text(statusLine)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider()

                ScrollView {
                    // The Muilyzz pattern via the phraseHeader slot: each
                    // phrase carries its own slice of the media timeline.
                    LatticeGridView(source: sheet, selection: $selection) { beat in
                        Text(beat.ordinal.map(String.init) ?? "·")
                            .font(.caption2.monospacedDigit())
                    } phraseHeader: { phrase in
                        PhraseMediaStrip(
                            phrase: phrase,
                            timeMap: timeMap,
                            mediaSeconds: mediaSeconds
                        )
                    }
                }
            }
            .padding()
            .navigationTitle("MediaAlign")
        }
    }

    private var statusLine: String {
        let beat = (try? timeMap.continuousScoreBeat(forMediaTime: mediaSeconds)) ?? 0
        let commit = committedSeconds.map { String(format: "committed %.2f s", $0) } ?? "no commit yet"
        return String(
            format: "media %.2f s → beat %.2f · %@ · %@",
            mediaSeconds, beat, selection?.label ?? "before the score", commit
        )
    }
}

/// Injected into the grid's `phraseHeader` slot — a view extension the base
/// kit never anticipated: each phrase carries **its own slice of the media
/// timeline** (the Muilyzz pattern), with the playhead appearing inside
/// whichever phrase currently contains the media position.
struct PhraseMediaStrip: View {
    let phrase: ScoreStructureSpan
    let timeMap: MediaTimeMap
    let mediaSeconds: Double

    private var window: (start: Double, end: Double)? {
        guard
            let start = try? timeMap.mediaTime(forScoreTick: phrase.range.startTick),
            let end = try? timeMap.mediaTime(forScoreTick: phrase.range.endTick),
            end > start
        else { return nil }
        return (start, end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(phrase.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let window {
                    Text(String(format: "%.1f – %.1f s", window.start, window.end))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            if let window {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.25))
                        if (window.start..<window.end).contains(mediaSeconds) {
                            let fraction = (mediaSeconds - window.start) / (window.end - window.start)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 2.5)
                                .offset(x: geo.size.width * fraction)
                        }
                    }
                }
                .frame(height: 5)
            }
        }
    }
}

/// The continuous world as a bar: lead (before the downbeat), score body,
/// residual tail — regions computed *only* through MediaTimeMap.
struct MediaBar: View {
    let timeMap: MediaTimeMap
    let mediaDuration: Double
    let scoreEndTick: ScoreTick
    @Binding var mediaSeconds: Double
    /// Fires continuously while dragging — keep the work light (visuals,
    /// cheap derived state).
    var onScrub: (Double) -> Void
    /// Fires once when the drag ends — the authoritative event for heavy
    /// work (seek, loads, persistence).
    var onCommit: (Double) -> Void

    init(
        timeMap: MediaTimeMap,
        mediaDuration: Double,
        scoreEndTick: ScoreTick,
        mediaSeconds: Binding<Double>,
        onScrub: @escaping (Double) -> Void,
        onCommit: @escaping (Double) -> Void
    ) {
        self.timeMap = timeMap
        self.mediaDuration = mediaDuration
        self.scoreEndTick = scoreEndTick
        self._mediaSeconds = mediaSeconds
        self.onScrub = onScrub
        self.onCommit = onCommit
    }

    private var downbeatFraction: Double {
        ((try? timeMap.mediaTime(forScoreTick: 0)) ?? 0) / mediaDuration
    }

    private var scoreEndFraction: Double {
        ((try? timeMap.mediaTime(forScoreTick: scoreEndTick)) ?? mediaDuration) / mediaDuration
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                // Lead — media before the score exists.
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                // Score body on the media axis.
                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: width * (scoreEndFraction - downbeatFraction))
                    .offset(x: width * downbeatFraction)
                // Downbeat anchor line.
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
                    .offset(x: width * downbeatFraction)
                // Playhead.
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2)
                    .offset(x: width * (mediaSeconds / mediaDuration))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(max(value.location.x / width, 0), 1)
                        mediaSeconds = fraction * mediaDuration
                        onScrub(mediaSeconds)
                    }
                    .onEnded { value in
                        let fraction = min(max(value.location.x / width, 0), 1)
                        mediaSeconds = fraction * mediaDuration
                        onCommit(mediaSeconds)
                    }
            )
        }
    }
}
