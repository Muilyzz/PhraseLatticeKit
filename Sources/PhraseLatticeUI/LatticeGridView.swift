import PhraseLattice
import SwiftUI

// MARK: - Barlines

/// Classifies a junction in the grid by the **highest boundary that begins
/// there**: a phrase start outranks a measure start outranks a beat.
public enum LatticeBoundaryKind: Sendable, Equatable, Hashable {
    case phrase
    case measure
    case beat
}

/// Generates the divider drawn at each lattice boundary — the "barline".
/// Conform to draw your own weights, colors, or double-bar styles.
public protocol BarlineProvider {
    associatedtype Line: View
    @ViewBuilder func barline(at kind: LatticeBoundaryKind) -> Line
}

/// Score-flavored default: the heavier the boundary, the heavier the line.
public struct DefaultBarlineProvider: BarlineProvider {
    public init() {}

    @ViewBuilder
    public func barline(at kind: LatticeBoundaryKind) -> some View {
        switch kind {
        case .phrase:
            Rectangle().fill(.secondary).frame(width: 2)
        case .measure:
            Rectangle().fill(.tertiary).frame(width: 1)
        case .beat:
            Rectangle().fill(.quaternary).frame(width: 0.5)
        }
    }
}

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
    /// The boundary this measure begins on: `.phrase` for the first measure
    /// of a phrase, `.measure` otherwise.
    public let leadingBoundary: LatticeBoundaryKind
}

/// The beats row the grid builds for one measure — receive it in your
/// `measure` slot and wrap it however you like. Beat cells, widths,
/// selection, taps, and beat/leading barlines are already inside.
public struct MeasureBeatsRow<BeatCell: View, Bars: BarlineProvider>: View {
    let beats: [ScoreStructureSpan]
    let beatWidth: CGFloat
    let leadingBoundary: LatticeBoundaryKind
    let barlines: Bars
    @Binding var selection: ScoreStructureSpan?
    let beatCell: (ScoreStructureSpan) -> BeatCell

    public var body: some View {
        HStack(spacing: 0) {
            barlines.barline(at: leadingBoundary)
            ForEach(Array(beats.enumerated()), id: \.element.id) { index, beatSpan in
                if index > 0 {
                    barlines.barline(at: .beat)
                }
                beatCell(beatSpan)
                    // Text law: one font size computed from the cell width so
                    // every cell reads consistently; content may shrink
                    // further to fit but never truncates ("…") or wraps.
                    .font(.system(size: max(8, beatWidth * 0.5)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
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
public struct DefaultMeasureBox<BeatCell: View, Bars: BarlineProvider>: View {
    public let context: LatticeMeasureContext
    public let beats: MeasureBeatsRow<BeatCell, Bars>

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
/// headers, barlines).
public struct LatticeGridView<
    BeatCell: View,
    MeasureBox: View,
    PhraseHeader: View,
    Bars: BarlineProvider
>: View {
    private struct PhraseRow {
        var phrase: ScoreStructureSpan
        var measures: [(measure: ScoreStructureSpan, beats: [ScoreStructureSpan])]
    }

    private let rows: [PhraseRow]
    private let beatWidth: CGFloat
    private let barlines: Bars
    @Binding private var selection: ScoreStructureSpan?
    private let beatCell: (ScoreStructureSpan) -> BeatCell
    private let measureBox: (LatticeMeasureContext, MeasureBeatsRow<BeatCell, Bars>) -> MeasureBox
    private let phraseHeader: (ScoreStructureSpan) -> PhraseHeader

    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        barlines: Bars,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell,
        @ViewBuilder measure: @escaping (LatticeMeasureContext, MeasureBeatsRow<BeatCell, Bars>) -> MeasureBox,
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
        self.barlines = barlines
        self._selection = selection
        self.beatCell = beat
        self.measureBox = measure
        self.phraseHeader = phraseHeader
    }

    @State private var gridWidth: CGFloat = 0

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rows, id: \.phrase.id) { row in
                VStack(alignment: .leading, spacing: 4) {
                    phraseHeader(row.phrase)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(measureRowPartition(row), id: \.self) { indices in
                            HStack(spacing: 8) {
                                ForEach(indices, id: \.self) { index in
                                    measureCell(row, index: index)
                                }
                            }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { gridWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        gridWidth = newWidth
                    }
            }
        )
    }

    private func measureCell(_ row: PhraseRow, index: Int) -> some View {
        let group = row.measures[index]
        let context = LatticeMeasureContext(
            measure: group.measure,
            isSelected: selection?.id == group.measure.id,
            leadingBoundary: index == 0 ? .phrase : .measure
        )
        return measureBox(
            context,
            MeasureBeatsRow(
                beats: group.beats,
                beatWidth: beatWidth,
                leadingBoundary: context.leadingBoundary,
                barlines: barlines,
                selection: $selection,
                beatCell: beatCell
            )
        )
    }

    /// Wraps measures by **binary fold**, not greedy flow: a wrap point reads
    /// as a musical signal, and a 4-measure phrase wrapped 3+1 visually lies
    /// about its hypermeter. When a phrase overflows, it folds in half —
    /// 4 becomes 2+2, 8 becomes 4+4 — so every line stays a legible musical
    /// unit. Explicit ``SystemBreak`` pins remain the host-side override for
    /// hand-chosen wrap points.
    ///
    /// Width is estimated from beat counts (meter changes only sit at phrase
    /// starts, so measures within one phrase share a beat count).
    private func measureRowPartition(_ row: PhraseRow) -> [[Int]] {
        let count = row.measures.count
        guard count > 0 else { return [] }
        let beatsPerMeasure = row.measures[0].beats.count
        let estimatedWidth = CGFloat(beatsPerMeasure) * beatWidth + 8
        let available = max(gridWidth - 12, estimatedWidth)
        let fit = max(1, Int((available + 8) / (estimatedWidth + 8)))

        var sizes: [Int] = []
        func fold(_ n: Int) {
            if n <= fit {
                sizes.append(n)
                return
            }
            let half = (n + 1) / 2
            fold(half)
            fold(n - half)
        }
        fold(count)

        var partition: [[Int]] = []
        var start = 0
        for size in sizes {
            partition.append(Array(start..<(start + size)))
            start += size
        }
        return partition
    }
}

// MARK: - Default-slot conveniences

extension LatticeGridView
where
    MeasureBox == DefaultMeasureBox<BeatCell, Bars>,
    PhraseHeader == DefaultPhraseHeader,
    Bars == DefaultBarlineProvider
{
    /// Custom beat cells; everything else default.
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
            barlines: DefaultBarlineProvider(),
            beat: beat,
            measure: { DefaultMeasureBox(context: $0, beats: $1) },
            phraseHeader: { DefaultPhraseHeader(phrase: $0) }
        )
    }
}

extension LatticeGridView
where MeasureBox == DefaultMeasureBox<BeatCell, Bars>, Bars == DefaultBarlineProvider {
    /// Custom beat cells and phrase headers; default measures and barlines.
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
            barlines: DefaultBarlineProvider(),
            beat: beat,
            measure: { DefaultMeasureBox(context: $0, beats: $1) },
            phraseHeader: phraseHeader
        )
    }
}

extension LatticeGridView
where PhraseHeader == DefaultPhraseHeader, Bars == DefaultBarlineProvider {
    /// Custom beat cells and measure boxes; default headers and barlines.
    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell,
        @ViewBuilder measure: @escaping (LatticeMeasureContext, MeasureBeatsRow<BeatCell, Bars>) -> MeasureBox
    ) {
        self.init(
            source: source,
            selection: selection,
            beatWidth: beatWidth,
            barlines: DefaultBarlineProvider(),
            beat: beat,
            measure: measure,
            phraseHeader: { DefaultPhraseHeader(phrase: $0) }
        )
    }
}

extension LatticeGridView
where
    MeasureBox == DefaultMeasureBox<BeatCell, Bars>,
    PhraseHeader == DefaultPhraseHeader
{
    /// Custom beat cells and barline provider; default measures and headers.
    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        barlines: Bars,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell
    ) {
        self.init(
            source: source,
            selection: selection,
            beatWidth: beatWidth,
            barlines: barlines,
            beat: beat,
            measure: { DefaultMeasureBox(context: $0, beats: $1) },
            phraseHeader: { DefaultPhraseHeader(phrase: $0) }
        )
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
