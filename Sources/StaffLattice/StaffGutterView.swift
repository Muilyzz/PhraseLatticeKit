import PhraseLattice
import SwiftUI

/// Notation front matter for PhraseLatticeKit's `phraseGutter` slot — the
/// **non-time space** before a system: clef and meter glyphs.
///
/// The gutter reuses the same coordinate story as every lane: it simply sits
/// before x = 0 of the time axis, so the lattice's alignment laws are
/// untouched. Pass the height of your staff lane so the clef centers on the
/// staff below the beats row.
public struct StaffGutterView: View {
    public let meter: MeterSignature
    public let staffLaneHeight: CGFloat

    public init(meter: MeterSignature, staffLaneHeight: CGFloat) {
        self.meter = meter
        self.staffLaneHeight = staffLaneHeight
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 10) {
            VStack(spacing: -2) {
                Text("\(meter.numerator)")
                Text("\(meter.denominator)")
            }
            .font(.system(size: 13, weight: .bold, design: .serif).monospacedDigit())
            Text("𝄞")
                .font(.system(size: staffLaneHeight * 0.42))
                .frame(height: staffLaneHeight)
        }
        .padding(.trailing, 8)
        .padding(.leading, 2)
    }
}
