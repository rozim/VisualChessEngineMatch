import XCTest
import Combine
@testable import VisualChessEngineMatch

@MainActor
final class MatchOrchestratorTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    func testMultiGameMatchFlow() async throws {
        let stockfishPath = "/usr/local/bin/stockfish"
        
        let orchestrator = MatchOrchestrator()
        let config = MatchConfig(
            miniMatchCount: 1, // 2 games total
            epdFilePath: nil,
            engine1: EngineConfig(name: "Stockfish 1", binaryPath: stockfishPath, timePerGame: 5, incrementPerMove: 0.1, uciOptions: [:]),
            engine2: EngineConfig(name: "Stockfish 2", binaryPath: stockfishPath, timePerGame: 5, incrementPerMove: 0.1, uciOptions: [:])
        )

        orchestrator.startMatch(config: config)
        
        // Wait for first game to start
        let start = Date()
        while orchestrator.score.gamesPlayed == 0 && Date().timeIntervalSince(start) < 15 {
            if case .gameOver = orchestrator.state {
                // Game ended naturally (or by error)
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        
        // Wait for first game to finish and second to start
        let start2 = Date()
        while orchestrator.score.gamesPlayed < 1 && Date().timeIntervalSince(start2) < 15 {
             try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        XCTAssertGreaterThanOrEqual(orchestrator.score.gamesPlayed, 1)
        
        // Check if colors swapped (Engine 2 should be white in game 2)
        // This is hard to check directly as whitePlayer is private.
        // But we can check the state.
        
        // Wait for second game to finish or progress
        let start3 = Date()
        while orchestrator.score.gamesPlayed < 2 && Date().timeIntervalSince(start3) < 15 {
             try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        XCTAssertEqual(orchestrator.score.gamesPlayed, 2)
        
        // Match should be over
        let start4 = Date()
        while !isMatchOver(orchestrator.state) && Date().timeIntervalSince(start4) < 5 {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        XCTAssertTrue(isMatchOver(orchestrator.state))
        
        orchestrator.stopMatch()
    }
    
    private func isMatchOver(_ state: MatchOrchestrator.State) -> Bool {
        if case .matchOver = state { return true }
        return false
    }
}
