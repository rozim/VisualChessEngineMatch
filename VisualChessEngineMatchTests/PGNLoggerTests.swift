import XCTest
@testable import VisualChessEngineMatch

final class PGNLoggerTests: XCTestCase {

    func testGeneratePGN() {
        let info = PGNLogger.GameInfo(
            event: "Test Event",
            site: "Test Site",
            date: "2026.05.31",
            round: "1",
            white: "Engine1",
            black: "Engine2",
            result: "1-0",
            fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
            moves: ["e4", "e5", "Nf3", "Nc6"]
        )
        
        let pgn = PGNLogger.generatePGN(info: info)
        
        XCTAssertTrue(pgn.contains("[Event \"Test Event\"]"))
        XCTAssertTrue(pgn.contains("[Result \"1-0\"]"))
        XCTAssertTrue(pgn.contains("[FEN \"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1\"]"))
        XCTAssertTrue(pgn.contains("1. e4 e5 2. Nf3 Nc6 1-0"))
    }

    func testAppendToLog() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PGNLoggerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logURL = tempDir.appendingPathComponent("match.pgn")
        let pgn1 = "[Event \"Game 1\"]\n\n1. e4 1-0\n\n"
        let pgn2 = "[Event \"Game 2\"]\n\n1. d4 0-1\n\n"
        
        try PGNLogger.appendToLog(pgn: pgn1, filePath: logURL.path)
        try PGNLogger.appendToLog(pgn: pgn2, filePath: logURL.path)
        
        let content = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertEqual(content, pgn1 + pgn2)
    }
}
