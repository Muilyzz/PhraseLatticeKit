import PhraseLattice
import SwiftUI

/// Minimal renderer for the lattice projection: phrases as rows, measures as
/// bordered groups, beats as cells.
///
/// The UI twin of the ``ScoreStructureSource`` seam: **layout is the product,
/// content is injected.** The grid never learns what lives inside a beat — a
/// chord, a lyric, a color — the `beat` slot decides. Selection is a plain
/// binding; drive it from taps here or from arrow keys via
/// ``ScoreStructureCursor`` outside.
public struct LatticeGridView<BeatCell: View>: View {
    private struct PhraseRow {
        var phrase: ScoreStructureSpan
        var measures: [(measure: ScoreStructureSpan, beats: [ScoreStructureSpan])]
    }

    private let rows: [PhraseRow]
    @Binding private var selection: ScoreStructureSpan?
    private let beatCell: (ScoreStructureSpan) -> BeatCell

    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell
    ) {
        self.rows = ScoreStructureIndex.phraseSpans(in: source).map { phrase in
            PhraseRow(
                phrase: phrase,
                measures: ScoreStructureIndex.children(of: phrase, in: source).map { measure in
                    (measure, ScoreStructureIndex.children(of: measure, in: source))
                }
            )
        }
        self._selection = selection
        self.beatCell = beat
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rows, id: \.phrase.id) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.phrase.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(row.measures, id: \.measure.id) { group in
                            HStack(spacing: 2) {
                                ForEach(group.beats, id: \.id) { beatSpan in
                                    beatCell(beatSpan)
                                        .frame(maxWidth: .infinity)
                                        .padding(4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(
                                                    selection?.id == beatSpan.id
                                                        ? Color.accentColor.opacity(0.25)
                                                        : Color.clear
                                                )
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture { selection = beatSpan }
                                }
                            }
                            .padding(2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
private struct PreviewSheet: ScoreStructureSource {
    let id = UUID()
    var title = "Preview"
    var durationTicks = 8 * 96
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { [] }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

#Preview("Lattice grid") {
    @Previewable @State var selection: ScoreStructureSpan?
    return ScrollView {
        LatticeGridView(source: PreviewSheet(), selection: $selection) { beat in
            Text(beat.ordinal.map(String.init) ?? "·")
                .font(.caption2.monospacedDigit())
        }
        .padding()
    }
}
#endif
