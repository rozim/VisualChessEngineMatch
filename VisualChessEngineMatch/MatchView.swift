import SwiftUI

/// Primary view for observing an engine match.
struct MatchView: View {
    @ObservedObject var orchestrator: MatchOrchestrator
    
    var body: some View {
        HStack(spacing: 20) {
            // Left column: Eval bars and Board
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    let eval1 = engineEval(info: orchestrator.player1Info, isWhite: orchestrator.player1 === orchestrator.whitePlayer)
                    EvalBarView(fraction: eval1.fraction, label: eval1.label)
                    
                    let eval2 = engineEval(info: orchestrator.player2Info, isWhite: orchestrator.player2 === orchestrator.whitePlayer)
                    EvalBarView(fraction: eval2.fraction, label: eval2.label)
                }
                
                VStack(spacing: 12) {
                    playerHeader(player: blackPlayer(), info: blackInfo(), color: .black)
                    
                    BoardView(controller: orchestrator.controller, isInteractive: false)
                        .frame(minWidth: 400, minHeight: 400)
                    
                    playerHeader(player: whitePlayer(), info: whiteInfo(), color: .white)
                }
            }
            
            // Right column: Match info and move list
            VStack(alignment: .leading, spacing: 16) {
                matchStatusCard()
                
                Text("Move History")
                    .font(.headline)
                
                moveHistoryList()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(width: 240)
        }
        .padding()
    }
    
    // MARK: - Subviews
    
    private func playerHeader(player: MatchPlayer?, info: UCIInfo?, color: PieceColor) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(player?.name ?? (color == .white ? "White" : "Black"))
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(alignment: .center, spacing: 4) {
                    Text("PV:")
                        .frame(height: 22)
                    Group {
                        if let pv = info?.pv, !pv.isEmpty {
                            let moves = orchestrator.controller.game.sanLine(forUCIMoves: pv, figurine: true)
                            FigurineSANLine(moves: moves, baseFont: .caption, figurineSize: 16)
                        } else {
                            Text("...")
                                .frame(height: 22)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 22, alignment: .leading)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(orchestrator.clock?.timeMs(for: color) ?? 0))
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                    .foregroundStyle(isThinking(player) ? .primary : .secondary)
                
                Group {
                    if let nps = info?.nps {
                        Text("\(nps / 1000) kN/s")
                    } else {
                        Text(" ") // Keeps space even when engine is idle
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 14)
            }
        }
        .padding(8)
        .background(isThinking(player) ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func matchStatusCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Match Score")
                    .font(.headline)
                Spacer()
                Text("\(formatScore(orchestrator.score.engine1Score)) - \(formatScore(orchestrator.score.engine2Score))")
                    .font(.headline)
                    .bold()
            }
            
            Divider()
            
            Group {
                switch orchestrator.state {
                case .playing(let num, let total):
                    Text("Game \(num) of \(total)")
                case .gameOver(_, let reason):
                    Text("Game Over: \(reason)")
                        .foregroundStyle(.orange)
                case .matchOver:
                    Text("Match Finished")
                        .bold()
                        .foregroundStyle(.green)
                case .error(let msg):
                    Text("Error: \(msg)")
                        .foregroundStyle(.red)
                default:
                    Text("Ready")
                }
            }
            .font(.subheadline)
            .lineLimit(2)
            .frame(height: 36, alignment: .topLeading) // Fixed height prevents card growth
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 1)
    }
    
    private func moveHistoryList() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    let history = orchestrator.controller.figurineHistory
                    ForEach(0..<Int(ceil(Double(history.count) / 2.0)), id: \.self) { i in
                        HStack {
                            Text("\(i + 1).")
                                .frame(width: 30, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            
                            FigurineSANText(san: history[i * 2], baseFont: .body, figurineSize: 22)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if i * 2 + 1 < history.count {
                                FigurineSANText(san: history[i * 2 + 1], baseFont: .body, figurineSize: 22)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(i % 2 == 0 ? Color.clear : Color.black.opacity(0.03))
                        .id(i)
                    }
                }
            }
            .onChange(of: orchestrator.controller.figurineHistory.count) {
                let lastIndex = (orchestrator.controller.figurineHistory.count - 1) / 2
                withAnimation { proxy.scrollTo(lastIndex, anchor: .bottom) }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func whitePlayer() -> MatchPlayer? {
        orchestrator.whitePlayer
    }
    
    private func blackPlayer() -> MatchPlayer? {
        orchestrator.blackPlayer
    }
    
    private func whiteInfo() -> UCIInfo? {
        orchestrator.whiteInfo
    }
    
    private func blackInfo() -> UCIInfo? {
        orchestrator.blackInfo
    }
    
    private func isThinking(_ player: MatchPlayer?) -> Bool {
        player?.state == .thinking
    }
    
    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let tenths = (ms % 1000) / 100
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
    
    private func formatScore(_ score: Double) -> String {
        if score == floor(score) {
            return String(format: "%.0f", score)
        } else {
            return String(format: "%.1f", score)
        }
    }
    
    private func engineEval(info: UCIInfo?, isWhite: Bool) -> (fraction: Double?, label: String?) {
        guard let info = info else { return (nil, nil) }
        
        let label: String
        let winProb: Double
        
        if let mate = info.scoreMate {
            label = "M\(abs(mate))"
            winProb = mate > 0 ? 1.0 : 0.0
        } else {
            let cp = info.scoreCentipawns ?? 0
            label = String(format: "%+.2f", Double(cp) / 100.0)
            // Sigmoid: 1 / (1 + 10^(-cp/400))
            winProb = 1.0 / (1.0 + pow(10.0, -Double(cp) / 400.0))
        }
        
        // Normalize to White perspective.
        // info.scoreCentipawns is relative to the side that was searching.
        // If the searching engine is White, winProb is whiteWinProb.
        // If the searching engine is Black, winProb is blackWinProb, so whiteWinProb is 1.0 - winProb.
        let whiteWinProb = isWhite ? winProb : (1.0 - winProb)
        return (whiteWinProb, label)
    }
}
