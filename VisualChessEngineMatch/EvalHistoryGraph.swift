import SwiftUI
import Charts

/// A bar graph showing engine evaluation over time (one bar per move).
struct EvalHistoryGraph: View {
    let history: [Double]
    let engineName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(engineName)
                .font(.caption).bold()
                .foregroundStyle(.secondary)
            
            Chart {
                ForEach(history.indices, id: \.self) { i in
                    BarMark(
                        x: .value("Move", i),
                        y: .value("Win Prob", history[i] - 0.5) // Center at 0.5
                    )
                    .foregroundStyle(history[i] >= 0.5 ? Color.blue.gradient : Color.red.gradient)
                }
            }
            .chartYScale(domain: -0.5...0.5)
            .chartYAxis {
                AxisMarks(values: [-0.5, 0, 0.5]) { value in
                    AxisGridLine()
                    AxisTick()
                    if let doubleValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text(String(format: "%.1f", doubleValue + 0.5))
                                .font(.system(size: 8))
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 60)
        }
        .padding(8)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VStack {
        EvalHistoryGraph(history: [0.5, 0.55, 0.45, 0.6, 0.3, 0.8, 0.9], engineName: "Engine 1")
        EvalHistoryGraph(history: [0.5, 0.48, 0.52, 0.4, 0.2, 0.1, 0.05], engineName: "Engine 2")
    }
    .padding()
    .frame(width: 300)
}
