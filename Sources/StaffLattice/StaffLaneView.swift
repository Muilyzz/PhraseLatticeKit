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

/// Shared drawing for the grand staff (both views use the same fixed step
/// window from ``StaffGeometry``, so gutter and lane lines align).
enum GrandStaffDrawing {
    static func drawLines(_ context: GraphicsContext, size: CGSize) {
        for lineStep in StaffGeometry.trebleLineSteps + StaffGeometry.bassLineSteps {
            let lineY = StaffGeometry.y(forStep: lineStep, height: size.height)
            context.stroke(
                Path { $0.move(to: CGPoint(x: 0, y: lineY))
                       $0.addLine(to: CGPoint(x: size.width, y: lineY)) },
                with: .color(.secondary.opacity(0.45)),
                lineWidth: 0.7
            )
        }
    }
}

/// A **grand staff** drawn in PhraseLatticeUI's `phraseFooter` lane —
/// one Canvas per phrase, no per-note view identity.
///
/// Time is lattice-linear (x = f(tick), the lane shares the system's
/// endpoints); pitch placement is phenotype-driven on one continuous
/// diatonic step axis, so the treble/bass separation is exactly the
/// scientific degree gap (A3 … E4 with middle C between).
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
            GrandStaffDrawing.drawLines(context, size: size)

            func y(_ step: Int) -> CGFloat {
                StaffGeometry.y(forStep: step, height: size.height)
            }
            let half = size.height / CGFloat(
                StaffGeometry.grandStaffStepRange.upperBound
                    - StaffGeometry.grandStaffStepRange.lowerBound
            )

            // Signature accidentals on both staves.
            let signatureGlyph = signature.fifths >= 0 ? "♯" : "♭"
            let signatureSteps = StaffGeometry.trebleSignatureSteps(for: signature)
                + StaffGeometry.bassSignatureSteps(for: signature)
            for (index, sigStep) in signatureSteps.enumerated() {
                let column = index % StaffGeometry.trebleSignatureSteps(for: signature).count
                context.draw(
                    Text(signatureGlyph)
                        .font(.system(size: half * 3.4))
                        .foregroundStyle(.secondary),
                    at: CGPoint(x: 6 + CGFloat(column) * half * 2.2, y: y(sigStep))
                )
            }

            // Notes: time-linear x, phenotype-step y.
            let duration = CGFloat(phrase.range.durationTicks)
            let inPhrase = notes.filter { phrase.range.contains($0.tick) }
            for note in inPhrase {
                let spelled = KeySpellingPolicy.spell(midi: note.midi, in: signature)
                let x = CGFloat(note.tick - phrase.range.startTick) / duration * size.width
                let step = StaffGeometry.step(of: spelled)
                let noteY = y(step)

                for ledgerStep in StaffGeometry.grandLedgerSteps(for: step) {
                    let ledgerY = y(ledgerStep)
                    context.stroke(
                        Path { $0.move(to: CGPoint(x: x - half * 0.7, y: ledgerY))
                               $0.addLine(to: CGPoint(x: x + half * 2.6, y: ledgerY)) },
                        with: .color(.secondary.opacity(0.6)),
                        lineWidth: 0.7
                    )
                }

                let needsGlyph = spelled.accidental != signature.accidental(for: spelled.letter)
                if needsGlyph {
                    let glyph = spelled.accidental == .natural ? "♮" : spelled.accidental.symbol
                    context.draw(
                        Text(glyph).font(.system(size: half * 3.0)).foregroundStyle(.primary),
                        at: CGPoint(x: x - half * 1.3, y: noteY)
                    )
                }

                let head = CGRect(
                    x: x, y: noteY - half * 0.72,
                    width: half * 2.0, height: half * 1.44
                )
                context.fill(Ellipse().path(in: head), with: .color(.primary))
            }
        }
    }
}
