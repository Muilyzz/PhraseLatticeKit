import PhraseLattice
import SwiftUI

// MARK: - Slot contexts & default renderers

/// Default phrase header — a small secondary label. Replace it by passing
/// your own `phraseHeader` slot to ``LatticeGridView``.
public struct DefaultPhraseHeader: View {
    public let phrase: ScoreStructureSpan

    public init(phrase: ScoreStructureSpan) {
        self.phrase = phrase
    }

    public var body: some View {
        Text(phrase.label)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

/// Everything a measure (bar) renderer needs beyond its beats.
public struct LatticeMeasureContext {
    public let measure: ScoreStructureSpan
    public let isSelected: Bool
}

/// The beats row the grid builds for one measure — receive it in your
/// `measure` slot and wrap it however you like. Beat cells, widths,
/// selection highlight, and taps are already inside.
public struct MeasureBeatsRow<BeatCell: View>: View {
    let beats: [ScoreStructureSpan]
    let beatWidth: CGFloat
    @Binding var selection: ScoreStructureSpan?
    let beatCell: (ScoreStructureSpan) -> BeatCell

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(beats, id: \.id) { beatSpan in
                beatCell(beatSpan)
                    .frame(width: beatWidth)
                    .padding(.vertical, 6)
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
    }
}

/// Default measure (bar) renderer: thin rounded border, accent when the
/// cursor sits on the measure.
public struct DefaultMeasureBox<BeatCell: View>: View {
    public let context: LatticeMeasureContext
    public let beats: MeasureBeatsRow<BeatCell>

    public var body: some View {
        beats
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        context.isSelected
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        context.isSelected
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(.quaternary),
                        lineWidth: context.isSelected ? 1.5 : 1
                    )
            )
    }
}

// MARK: - Grid

/// Minimal renderer for the lattice projection: phrases as sections, measures
/// as groups, beats as fixed-width cells.
///
/// The UI twin of the ``ScoreStructureSource`` seam: **the grid owns only the
/// fold and the "same time = same width" law** — every visible thing is an
/// injectable slot with a default renderer (beat cells, measure boxes, phrase
/// headers). Measures soft-wrap onto new lines when a phrase exceeds the
/// available width — the visual cousin of ``SystemBreak``.
public struct LatticeGridView<BeatCell: View, MeasureBox: View, PhraseHeader: View>: View {
    private struct PhraseRow {
        var phrase: ScoreStructureSpan
        var measures: [(measure: ScoreStructureSpan, beats: [ScoreStructureSpan])]
    }

    private let rows: [PhraseRow]
    private let beatWidth: CGFloat
    @Binding private var selection: ScoreStructureSpan?
    private let beatCell: (ScoreStructureSpan) -> BeatCell
    private let measureBox: (LatticeMeasureContext, MeasureBeatsRow<BeatCell>) -> MeasureBox
    private let phraseHeader: (ScoreStructureSpan) -> PhraseHeader

    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell,
        @ViewBuilder measure: @escaping (LatticeMeasureContext, MeasureBeatsRow<BeatCell>) -> MeasureBox,
        @ViewBuilder phraseHeader: @escaping (ScoreStructureSpan) -> PhraseHeader
    ) {
        self.rows = ScoreStructureIndex.phraseSpans(in: source).map { phrase in
            PhraseRow(
                phrase: phrase,
                measures: ScoreStructureIndex.children(of: phrase, in: source).map { measure in
                    (measure, ScoreStructureIndex.children(of: measure, in: source))
                }
            )
        }
        self.beatWidth = beatWidth
        self._selection = selection
        self.beatCell = beat
        self.measureBox = measure
        self.phraseHeader = phraseHeader
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rows, id: \.phrase.id) { row in
                VStack(alignment: .leading, spacing: 4) {
                    phraseHeader(row.phrase)
                    MeasureWrap(spacing: 8, lineSpacing: 8) {
                        ForEach(row.measures, id: \.measure.id) { group in
                            measureBox(
                                LatticeMeasureContext(
                                    measure: group.measure,
                                    isSelected: selection?.id == group.measure.id
                                ),
                                MeasureBeatsRow(
                                    beats: group.beats,
                                    beatWidth: beatWidth,
                                    selection: $selection,
                                    beatCell: beatCell
                                )
                            )
                        }
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            selection?.id == row.phrase.id
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                )
            }
        }
    }
}

// MARK: - Default-slot conveniences

extension LatticeGridView
where MeasureBox == DefaultMeasureBox<BeatCell>, PhraseHeader == DefaultPhraseHeader {
    /// Custom beat cells; default measure boxes and phrase headers.
    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell
    ) {
        self.init(
            source: source,
            selection: selection,
            beatWidth: beatWidth,
            beat: beat,
            measure: { DefaultMeasureBox(context: $0, beats: $1) },
            phraseHeader: { DefaultPhraseHeader(phrase: $0) }
        )
    }
}

extension LatticeGridView where MeasureBox == DefaultMeasureBox<BeatCell> {
    /// Custom beat cells and phrase headers; default measure boxes.
    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell,
        @ViewBuilder phraseHeader: @escaping (ScoreStructureSpan) -> PhraseHeader
    ) {
        self.init(
            source: source,
            selection: selection,
            beatWidth: beatWidth,
            beat: beat,
            measure: { DefaultMeasureBox(context: $0, beats: $1) },
            phraseHeader: phraseHeader
        )
    }
}

extension LatticeGridView where PhraseHeader == DefaultPhraseHeader {
    /// Custom beat cells and measure boxes; default phrase headers.
    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell,
        @ViewBuilder measure: @escaping (LatticeMeasureContext, MeasureBeatsRow<BeatCell>) -> MeasureBox
    ) {
        self.init(
            source: source,
            selection: selection,
            beatWidth: beatWidth,
            beat: beat,
            measure: measure,
            phraseHeader: { DefaultPhraseHeader(phrase: $0) }
        )
    }
}

// MARK: - Flow layout

/// Left-aligned flow layout: keeps every measure at its intrinsic width
/// (beats × beatWidth) and wraps to a new line when the phrase overflows.
private struct MeasureWrap: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: .unspecified
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
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
    var phraseBoundaries: [PhraseBoundary] { [PhraseBoundary(tick: 480)] }
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
