import PhraseLattice
import PhraseLatticeUI
import SwiftUI

/// A complete consumer in one file: a lyric sheet (no harmony, no media)
/// adopts the seven-member seam and gets projection, grid, and cursor.
struct LyricSheet: ScoreStructureSource {
    let id = UUID()
    var title = "Lattice example"
    /// 8 bars of 4/4 (bar = 4 × 24 ticks = 96).
    var durationTicks = 8 * 96
    var pins: [ScoreTick] = []
    var meterMap = MeterMap(events: [
        MeterEvent(tick: 0, signature: MeterSignature(numerator: 4, denominator: 4)),
    ])
    var pickupTicks: Int { 0 }
    var phraseBoundaries: [PhraseBoundary] { pins.map { PhraseBoundary(tick: $0) } }
    func bar(containing tick: ScoreTick) throws -> DerivedBar? {
        try meterMap.bar(containing: tick, pickupTicks: pickupTicks)
    }
}

@main
struct LatticeGridExampleApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var pinned = false
    @State private var selection: ScoreStructureSpan?

    private var sheet: LyricSheet {
        LyricSheet(pins: pinned ? [480] : [])   // bar 6 hinge
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LatticeGridView(source: sheet, selection: $selection) { beat in
                    Text(beat.ordinal.map(String.init) ?? "·")
                        .font(.caption.monospacedDigit())
                }
                .padding()
            }
            .navigationTitle("PhraseLattice")
            .safeAreaInset(edge: .bottom) { controls }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Toggle("Pin a phrase hinge at bar 6", isOn: $pinned)
                .font(.callout)
            HStack(spacing: 14) {
                arrow("arrow.left", .left)
                arrow("arrow.right", .right)
                arrow("arrow.up", .up)
                arrow("arrow.down", .down)
                Spacer()
                Text(selection?.label ?? "nothing selected")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.bar)
    }

    private func arrow(_ symbol: String, _ direction: ScoreStructureCursorDirection) -> some View {
        Button {
            selection = ScoreStructureCursor.move(from: selection, direction: direction, in: sheet)
        } label: {
            Image(systemName: symbol).frame(width: 34, height: 30)
        }
        .buttonStyle(.bordered)
    }
}
