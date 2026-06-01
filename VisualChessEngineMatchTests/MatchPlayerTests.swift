import XCTest
import Combine
@testable import VisualChessEngineMatch

@MainActor
final class MatchPlayerTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    func testHandshakeAndMoveGeneration() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MatchPlayerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let engineURL = tempDir.appendingPathComponent("mock-engine.sh")
        let script = """
        #!/bin/bash
        while IFS= read -r line; do
          if [[ "$line" == "uci" ]]; then
            echo "id name MockEngine"
            echo "uciok"
          elif [[ "$line" == "isready" ]]; then
            echo "readyok"
          elif [[ "$line" == go* ]]; then
            echo "info depth 1 score cp 13 pv e2e4"
            echo "bestmove e2e4"
          fi
        done
        """
        try script.write(to: engineURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: engineURL.path)

        let player = MatchPlayer()
        let config = EngineConfig(name: "Test", binaryPath: engineURL.path, timePerGame: 10, incrementPerMove: 0, nodeLimit: 1000, uciOptions: [:])

        var stateHistory: [MatchPlayer.State] = []
        player.$state.sink { stateHistory.append($0) }.store(in: &cancellables)

        player.start(config: config)
        
        // Polling wait for ready state
        let start = Date()
        while !stateHistory.contains(.ready) && Date().timeIntervalSince(start) < 5 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        XCTAssertEqual(player.state, .ready)
        XCTAssertTrue(player.name.contains("MockEngine"))

        var infoReceived = false
        player.infoPublisher.sink { info in
            if info.scoreCentipawns == 13 { infoReceived = true }
        }.store(in: &cancellables)

        var bestMove: String?
        player.bestMovePublisher.sink { bestMove = $0 }.store(in: &cancellables)

        player.search(state: .standard, clock: MatchClock(whiteTime: 10, blackTime: 10), mode: .time, nodeLimit: 1000)
        
        let start2 = Date()
        while (bestMove == nil || !infoReceived) && Date().timeIntervalSince(start2) < 5 {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        XCTAssertEqual(bestMove, "e2e4")
        XCTAssertTrue(infoReceived)
        
        player.stop()
    }
}
