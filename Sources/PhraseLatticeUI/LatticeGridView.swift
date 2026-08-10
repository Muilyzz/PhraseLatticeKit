import PhraseLattice
import SwiftUI

/// Minimal renderer for the lattice projection: phrases as sections, measures
/// as bordered groups, beats as fixed-width cells.
///
/// The UI twin of the ``ScoreStructureSource`` seam: **layout is the product,
/// content is injected.** The grid never learns what lives inside a beat — a
/// chord, a lyric, a color — the `beat` slot decides.
///
/// Grid law: **same time = same width.** Every beat gets `beatWidth` points,
/// so a one-bar phrase draws narrow instead of stretching. Measures soft-wrap
/// onto new lines when a phrase exceeds the available width — the visual
/// cousin of ``SystemBreak``.
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

public struct LatticeGridView<BeatCell: View, PhraseHeader: View>: View {
    private struct PhraseRow {
        var phrase: ScoreStructureSpan
        var measures: [(measure: ScoreStructureSpan, beats: [ScoreStructureSpan])]
    }

    private let rows: [PhraseRow]
    private let beatWidth: CGFloat
    @Binding private var selection: ScoreStructureSpan?
    private let beatCell: (ScoreStructureSpan) -> BeatCell
    private let phraseHeader: (ScoreStructureSpan) -> PhraseHeader

    public init(
        source: some ScoreStructureSource,
        selection: Binding<ScoreStructureSpan?> = .constant(nil),
        beatWidth: CGFloat = 20,
        @ViewBuilder beat: @escaping (ScoreStructureSpan) -> BeatCell,
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
        self.phraseHeader = phraseHeader
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(rows, id: \.phrase.id) { row in
                VStack(alignment: .leading, spacing: 4) {
                    phraseHeader(row.phrase)
                    MeasureWrap(spacing: 8, lineSpacing: 8) {
                        ForEach(row.measures, id: \.measure.id) { group in
                            measureBox(group.beats)
                        }
                    }
                }
            }
        }
    }

    private func measureBox(_ beats: [ScoreStructureSpan]) -> some View {
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
        .padding(2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}

extension LatticeGridView where PhraseHeader == DefaultPhraseHeader {
    /// Convenience: default phrase header, custom beat cells only.
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
            phraseHeader: { DefaultPhraseHeader(phrase: $0) }
        )
    }
}

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
