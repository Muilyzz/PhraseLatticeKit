import PhraseLattice
import SwiftUI

/// Notation front matter for PhraseLatticeKit's `phraseGutter` slot — the
/// **non-time space** before a system, drawn the way scores draw it: the
/// grand-staff lines continue under the clefs and stacked meter fractions.
///
/// Uses the same fixed step window as ``StaffLaneView``, so its lines meet
/// the lane's lines exactly. Clefs are anchored music-theoretically: the
/// treble curl centers on the G4 line, the bass dots straddle the F3 line.
public struct StaffGutterView: View {
    public let meter: MeterSignature
    public let staffLaneHeight: CGFloat

    public init(meter: MeterSignature, staffLaneHeight: CGFloat) {
        self.meter = meter
        self.staffLaneHeight = staffLaneHeight
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
            let clefX = size.width * 0.30

            // Clefs, anchored by the pictorial rules: the treble curl wraps
            // the G4 line; the bass clef's two dots straddle the F3 line.
            // Offsets calibrated for the system font's glyph metrics.
            context.draw(
                Text("𝄞").font(.system(size: half * 9.5)),
                at: CGPoint(x: clefX, y: y(StaffGeometry.trebleClefAnchorStep) - half * 0.75)
            )
            context.draw(
                Text("𝄢").font(.system(size: half * 5.2)),
                at: CGPoint(x: clefX, y: y(StaffGeometry.bassClefAnchorStep) + half * 1.45)
            )

            // Stacked meter fractions on both staves.
            let fractionX = size.width * 0.72
            let fractionFont = Font.system(size: half * 3.6, weight: .bold, design: .serif)
            for (numeratorStep, denominatorStep) in [(36, 32), (24, 20)] {
                context.draw(
                    Text("\(meter.numerator)").font(fractionFont),
                    at: CGPoint(x: fractionX, y: y(numeratorStep))
                )
                context.draw(
                    Text("\(meter.denominator)").font(fractionFont),
                    at: CGPoint(x: fractionX, y: y(denominatorStep))
                )
            }
        }
        .frame(height: staffLaneHeight)
        .padding(.trailing, 2)
    }
}
