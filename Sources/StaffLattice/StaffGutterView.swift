import PhraseLattice
import SwiftUI

/// Notation front matter for PhraseLatticeKit's `phraseGutter` slot — the
/// **non-time space** before a system: clef and meter, written the way
/// scores write them (the meter as a stacked fraction beside the clef, on
/// the staff).
///
/// The gutter bottom-aligns with the row (kit law), so sizing this view to
/// the staff lane's height lines the clef and fraction up with the staff by
/// construction.
public struct StaffGutterView: View {
    public let meter: MeterSignature
    public let staffLaneHeight: CGFloat

    public init(meter: MeterSignature, staffLaneHeight: CGFloat) {
        self.meter = meter
        self.staffLaneHeight = staffLaneHeight
    }

    public var body: some View {
        HStack(alignment: .center, spacing: staffLaneHeight * 0.05) {
            Text("𝄞")
                .font(.system(size: staffLaneHeight * 0.42))
            VStack(spacing: -staffLaneHeight * 0.055) {
                Text("\(meter.numerator)")
                Text("\(meter.denominator)")
            }
            .font(.system(size: staffLaneHeight * 0.24, weight: .bold, design: .serif).monospacedDigit())
        }
        .frame(height: staffLaneHeight)
        .padding(.leading, 2)
        .padding(.trailing, 6)
    }
}
