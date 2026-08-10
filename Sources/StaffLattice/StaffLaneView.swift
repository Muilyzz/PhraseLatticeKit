import PhraseLattice
import SwiftUI

/// One note on the lattice: a genotype at a tick. The lane translates it to
/// a phenotype through the policy and places it by phenotype geometry.
public struct StaffNote: Sendable, Equatable, Hashable {
    public var tick: ScoreTick
    public var midi: Int

    public init(tick: ScoreTick, midi: Int) {
        self.tick = tick
        self.midi = midi
    }
}

/// A treble staff drawn in PhraseLatticeKit's `phraseFooter` lane —
/// **one Canvas per phrase**, no per-note view identity.
///
/// Time is lattice-linear (x = f(tick), the lane shares the system's
/// endpoints), pitch placement is phenotype-driven (letter + octave → staff
/// step; the accidental is a glyph, drawn only when it differs from the key
/// signature). The staff is the *unfolded* level of detail — a contour of
/// dots is the folded one; both read the same lane contract.
public struct StaffLaneView: View {
    public let phrase: ScoreStructureSpan
    public let notes: [StaffNote]
    public let signature: KeySignature

    public init(phrase: ScoreStructureSpan, notes: [StaffNote], signature: KeySignature) {
        self.phrase = phrase
        self.notes = notes
        self.signature = signature
    }

    public var body: some View {
        Canvas { context, size in
            let inPhrase = notes.filter { phrase.range.contains($0.tick) }
            let spelled = inPhrase.map {
                (note: $0, pitch: KeySpellingPolicy.spell(midi: $0.midi, in: signature))
            }

            // Vertical scale: fit staff plus the ledger range this phrase needs.
            let steps = spelled.map { StaffGeometry.step(of: $0.pitch) }
            let lowStep = min(StaffGeometry.trebleBottomLineStep - 2, steps.min() ?? 99)
            let highStep = max(StaffGeometry.trebleTopLineStep + 2, steps.max() ?? 0)
            let half = size.height / CGFloat(highStep - lowStep + 2)
            func y(_ step: Int) -> CGFloat {
                size.height - half * CGFloat(step - lowStep + 1)
            }

            // Five staff lines, full lane width.
            for lineStep in StaffGeometry.trebleLineSteps {
                let lineY = y(lineStep)
                context.stroke(
                    Path { $0.move(to: CGPoint(x: 0, y: lineY))
                           $0.addLine(to: CGPoint(x: size.width, y: lineY)) },
                    with: .color(.secondary.opacity(0.45)),
                    lineWidth: 0.7
                )
            }

            // Key signature accidentals at the lane's leading edge.
            let signatureGlyph = signature.fifths >= 0 ? "♯" : "♭"
            for (index, sigStep) in StaffGeometry.trebleSignatureSteps(for: signature).enumerated() {
                context.draw(
                    Text(signatureGlyph).font(.system(size: half * 3)).foregroundStyle(.secondary),
                    at: CGPoint(x: 6 + CGFloat(index) * half * 1.6, y: y(sigStep))
                )
            }

            // Notes: time-linear x, phenotype-step y.
            let duration = CGFloat(phrase.range.durationTicks)
            for entry in spelled {
                let x = CGFloat(entry.note.tick - phrase.range.startTick) / duration * size.width
                let step = StaffGeometry.step(of: entry.pitch)
                let noteY = y(step)

                // Ledger lines.
                for ledgerStep in StaffGeometry.trebleLedgerSteps(for: step) {
                    let ledgerY = y(ledgerStep)
                    context.stroke(
                        Path { $0.move(to: CGPoint(x: x - half * 0.6, y: ledgerY))
                               $0.addLine(to: CGPoint(x: x + half * 2.2, y: ledgerY)) },
                        with: .color(.secondary.opacity(0.6)),
                        lineWidth: 0.7
                    )
                }

                // Accidental glyph only when it differs from the signature.
                let needsGlyph = entry.pitch.accidental != signature.accidental(for: entry.pitch.letter)
                if needsGlyph {
                    let glyph = entry.pitch.accidental == .natural ? "♮" : entry.pitch.accidental.symbol
                    context.draw(
                        Text(glyph).font(.system(size: half * 2.6)).foregroundStyle(.primary),
                        at: CGPoint(x: x - half * 1.1, y: noteY)
                    )
                }

                // Notehead (slightly oblong ellipse).
                let head = CGRect(
                    x: x, y: noteY - half * 0.62,
                    width: half * 1.7, height: half * 1.24
                )
                context.fill(Ellipse().path(in: head), with: .color(.primary))
            }
        }
    }
}
