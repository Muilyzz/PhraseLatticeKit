import PhraseLattice
import PhraseLatticeUI
import StaffLattice
import SwiftUI

/// The top gutter holds the **selectors** (meter and key signature); the
/// left gutter holds the **glyphs** (clef and meter). Change the key — the
/// same genotypes respell live. Change the meter — the lattice refolds.
struct MelodySheet: ScoreStructureSource {
    let id = UUID()
    var title = "Staff lane"
    var durationTicks = 8 * 96
    /// Meter hinges — per the lattice law, meter statements sit at phrase
    /// starts. Two hinges here: tick 0 and tick 384.
    var meterA: MeterSignature
    var meterB: MeterSignature
    var meterMap: MeterMap {
        MeterMap(events: [
            MeterEvent(tick: 0, signature: meterA),
            MeterEvent(tick: 384, signature: meterB),
        ])
    }
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { [] }

    func meter(at tick: ScoreTick) -> MeterSignature {
        tick < 384 ? meterA : meterB
    }

    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

let melody: [StaffNote] = [
    .init(tick: 0, midi: 62), .init(tick: 24, midi: 66),
    .init(tick: 48, midi: 69), .init(tick: 72, midi: 74),
    .init(tick: 96, midi: 67), .init(tick: 120, midi: 66),
    .init(tick: 144, midi: 65), .init(tick: 168, midi: 64),
    .init(tick: 192, midi: 73), .init(tick: 216, midi: 72),
    .init(tick: 240, midi: 71), .init(tick: 264, midi: 69),
    .init(tick: 288, midi: 68), .init(tick: 312, midi: 67),
    .init(tick: 336, midi: 64), .init(tick: 360, midi: 60),
    .init(tick: 384, midi: 62), .init(tick: 408, midi: 66),
    .init(tick: 432, midi: 69), .init(tick: 456, midi: 74),
    .init(tick: 480, midi: 72), .init(tick: 504, midi: 71),
    .init(tick: 528, midi: 69), .init(tick: 552, midi: 67),
    .init(tick: 576, midi: 66), .init(tick: 600, midi: 65),
    .init(tick: 624, midi: 66), .init(tick: 648, midi: 69),
    .init(tick: 672, midi: 67), .init(tick: 696, midi: 66),
    .init(tick: 720, midi: 64), .init(tick: 744, midi: 62),
]

@main
struct StaffLaneExampleApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var fifths = 2
    @State private var beatsA = 4
    @State private var beatsB = 4
    @State private var selection: ScoreStructureSpan?

    private var signature: KeySignature { KeySignature(fifths: fifths) }
    private var sheet: MelodySheet {
        MelodySheet(
            meterA: MeterSignature(numerator: beatsA, denominator: 4),
            meterB: MeterSignature(numerator: beatsB, denominator: 4)
        )
    }

    /// Every phrase gets its own editable meter — the edit targets the
    /// hinge governing that phrase's start (meter changes are only legal
    /// at phrase starts, so the control sits exactly on the rule).
    private func meterBinding(for phrase: ScoreStructureSpan) -> Binding<Int> {
        phrase.range.startTick < 384 ? $beatsA : $beatsB
    }

    var body: some View {
        NavigationStack {
            // Fixed proportions: every height derives from the width, so
            // iPhone and iPad lay out the same shape (denser on iPhone).
            GeometryReader { geo in
                let contentWidth = geo.size.width - 32
                let staffHeight = contentWidth * 0.44
                let gutter = max(34, contentWidth * 0.105)

                ScrollView {
                    VStack(alignment: .leading, spacing: contentWidth * 0.03) {
                        Stepper(
                            value: $fifths, in: -7...7
                        ) {
                            Text(fifths >= 0 ? "♯\(fifths)" : "♭\(-fifths)")
                                .font(.callout.monospacedDigit().weight(.semibold))
                        }

                        LatticeGridView(
                            source: sheet,
                            selection: $selection,
                            gutterWidth: gutter
                        ) { beat in
                            Text(beat.ordinal.map(String.init) ?? "·")
                        } phraseHeader: { phrase in
                            Text(phrase.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        } phraseFooter: { phrase in
                            StaffLaneView(
                                phrase: phrase,
                                notes: melody,
                                signature: signature
                            )
                            .frame(height: staffHeight)
                            .padding(.top, 2)
                        } phraseGutter: { phrase in
                            // The editable horizontal meter lives in the
                            // gutter's upper space — left of the opening
                            // barline, at the chord-score row's level.
                            VStack(alignment: .leading, spacing: 6) {
                                Menu {
                                    Button("4/4") { meterBinding(for: phrase).wrappedValue = 4 }
                                    Button("2/4") { meterBinding(for: phrase).wrappedValue = 2 }
                                } label: {
                                    Text("\(sheet.meter(at: phrase.range.startTick).numerator)/4")
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                }
                                StaffGutterView(
                                    meter: sheet.meter(at: phrase.range.startTick),
                                    staffLaneHeight: staffHeight
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("StaffLattice")
        }
    }
}
