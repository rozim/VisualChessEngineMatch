import XCTest

@MainActor
final class DrawRulesTests: XCTestCase {

    private func play(_ controller: GameController, _ uci: String) {
        let move = Move(uci: uci)!
        controller.attemptMove(from: move.from, to: move.to)
    }

    // MARK: - Insufficient material (GameState)

    func testInsufficientMaterialTrueCases() {
        let drawn = [
            "8/8/8/4k3/8/4K3/8/8 w - - 0 1",     // K vs K
            "8/8/8/4k3/8/4K3/8/5B2 w - - 0 1",   // K+B vs K
            "8/8/8/4k3/8/4K3/8/5N2 w - - 0 1",   // K+N vs K
            "2b5/8/8/4k3/8/4K3/8/5B2 w - - 0 1", // bishops both on light squares
        ]
        for fen in drawn {
            XCTAssertTrue(GameState(fen: fen)!.hasInsufficientMaterial, "expected draw: \(fen)")
        }
    }

    func testInsufficientMaterialFalseCases() {
        let notDrawn = [
            "5b2/8/8/4k3/8/4K3/8/5B2 w - - 0 1", // bishops on opposite colors
            "5n2/8/8/4k3/8/4K3/8/5B2 w - - 0 1", // bishop + knight
            "8/8/8/4k3/8/4K3/8/5R2 w - - 0 1",   // a rook is present
            "8/8/8/4k3/8/4K3/4P3/8 w - - 0 1",   // a pawn is present
        ]
        for fen in notDrawn {
            XCTAssertFalse(GameState(fen: fen)!.hasInsufficientMaterial, "expected not-draw: \(fen)")
        }
    }

    func testControllerReportsInsufficientMaterial() {
        let c = GameController()
        c.load(fen: "8/8/8/4k3/8/4K3/8/5B2 w - - 0 1")
        XCTAssertEqual(c.result, .insufficientMaterial)
        XCTAssertTrue(c.isGameOver)
        XCTAssertEqual(c.statusText, "Draw — insufficient material")
    }

    // MARK: - Fifty-move rule

    func testFiftyMoveBoundary() {
        let c = GameController()
        // halfmove clock at 98: a quiet move makes 99 (not yet a draw).
        c.load(fen: "4k3/8/8/8/8/8/8/4K2R w - - 98 1")
        play(c, "h1h2")
        XCTAssertEqual(c.result, .ongoing)

        // halfmove clock at 99: a quiet move makes 100 (draw).
        c.load(fen: "4k3/8/8/8/8/8/8/4K2R w - - 99 1")
        play(c, "h1h2")
        XCTAssertEqual(c.result, .fiftyMove)
        XCTAssertTrue(c.isGameOver)
        XCTAssertEqual(c.statusText, "Draw — fifty-move rule")
    }

    // MARK: - Threefold repetition

    func testThreefoldRepetition() {
        let c = GameController()
        let shuffle = ["g1f3", "g8f6", "f3g1", "f6g8"]   // returns to the start position

        for uci in shuffle { play(c, uci) }              // start position seen twice
        XCTAssertEqual(c.result, .ongoing)

        for uci in shuffle { play(c, uci) }              // start position seen a third time
        XCTAssertEqual(c.result, .threefold)
        XCTAssertTrue(c.isGameOver)
        XCTAssertEqual(c.statusText, "Draw — threefold repetition")
    }

    func testUndoRestoresRepetitionCounts() {
        let c = GameController()
        for uci in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"] { play(c, uci) }
        XCTAssertEqual(c.result, .threefold)
        c.undo()                                          // back to two occurrences
        XCTAssertEqual(c.result, .ongoing)
    }

    // MARK: - Cache stays consistent (1.3)

    func testCachedLegalMovesMatchFreshComputation() {
        let c = GameController()
        play(c, "e2e4")
        play(c, "c7c5")
        XCTAssertEqual(Set(c.legalMovesCache), Set(c.game.legalMoves()))
    }
}
