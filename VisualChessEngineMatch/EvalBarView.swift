import SwiftUI

/// A vertical evaluation bar (White at the bottom, Black at the top) driven by
/// the engine's best line. Always oriented from White's point of view.
struct EvalBarView: View {
    /// White win fraction in 0...1 (0.5 = equal). Nil shows a neutral bar.
    let fraction: Double?
    /// Short score label (White-oriented), e.g. "+0.34" or "#3".
    let label: String?

    var body: some View {
        GeometryReader { geo in
            let f = fraction ?? 0.5
            let whiteHeight = geo.size.height * f
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color(white: 0.18))           // Black's share (top)
                Rectangle().fill(Color(white: 0.95))           // White's share (bottom)
                    .frame(height: whiteHeight)
                // Midline at equality.
                Rectangle().fill(Color.gray.opacity(0.6))
                    .frame(height: 1)
                    .offset(y: -geo.size.height / 2)
            }
            .overlay(alignment: f >= 0.5 ? .bottom : .top) {
                if let label {
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(f >= 0.5 ? Color.black : Color.white)
                        .padding(.vertical, 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(width: 16)
    }
}

#Preview {
    HStack {
        EvalBarView(fraction: 0.62, label: "+0.34")
        EvalBarView(fraction: 0.5, label: "0.00")
        EvalBarView(fraction: 1.0, label: "#3")
    }
    .frame(height: 360)
    .padding()
}
