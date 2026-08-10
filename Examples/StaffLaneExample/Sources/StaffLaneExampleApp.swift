import PhraseLattice
import PhraseLatticeUI
import StaffLattice
import SwiftUI

/// Genotypes on the lattice → phenotypes on a staff, in the grid's footer
/// lane. D major: watch F♯→F♮ and C♯→C♮ take a natural glyph (never a
/// flat), and chromatic G♯ take the sharp family.
struct MelodySheet: ScoreStructureSource {
    let id = UUID()
    var title = "Staff lane"
    var durationTicks = 8 * 96
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { [] }

    let signature = KeySignature(fifths: 2)

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

    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

@main
struct StaffLaneExampleApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    private let sheet = MelodySheet()
    @State private var selection: ScoreStructureSpan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("D major (♯2) — F♮ and C♮ cancel the signature; G♯ follows the family")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LatticeGridView(source: sheet, selection: $selection) { beat in
                        Text(beat.ordinal.map(String.init) ?? "·")
                    } phraseFooter: { phrase in
                        StaffLaneView(
                            phrase: phrase,
                            notes: sheet.melody,
                            signature: sheet.signature
                        )
                        .frame(height: 120)
                        .padding(.top, 2)
                    }
                }
                .padding()
            }
            .navigationTitle("StaffLattice")
        }
    }
}
