import XCTest

@MainActor
final class GameControllerTests: XCTestCase {

    private func sq(_ text: String) -> Square {
        let c = Array(text)
        return Square(file: Int(c[0].asciiValue! - Character("a").asciiValue!),
                      rank: Int(String(c[1]))! - 1)
    }

    func testLegalMoveIsApplied() {
        let c = GameController()
        XCTAssertEqual(c.attemptMove(from: sq("e2"), to: sq("e4")), .made)
        XCTAssertEqual(c.piece(at: sq("e4")), Piece(color: .white, kind: .pawn))
        XCTAssertNil(c.piece(at: sq("e2")))
        XCTAssertEqual(c.sideToMove, .black)
        XCTAssertEqual(c.moveHistory.count, 1)
    }

    func testIllegalMoveIsRejected() {
        let c = GameController()
        XCTAssertEqual(c.attemptMove(from: sq("e2"), to: sq("e5")), .illegal)
        XCTAssertEqual(c.sideToMove, .white)
        XCTAssertTrue(c.moveHistory.isEmpty)
    }

    func testPromotionRequiresChoiceThenApplies() {
        // White pawn on a7 about to promote.
        let c = GameController()
        c.load(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
        XCTAssertEqual(c.attemptMove(from: sq("a7"), to: sq("a8")), .needsPromotion)
        XCTAssertNil(c.piece(at: sq("a8")))  // nothing applied yet

        XCTAssertEqual(c.attemptMove(from: sq("a7"), to: sq("a8"), promotion: .queen), .made)
        XCTAssertEqual(c.piece(at: sq("a8")), Piece(color: .white, kind: .queen))
    }

    func testUndoRestoresPreviousPosition() {
        let c = GameController()
        c.attemptMove(from: sq("e2"), to: sq("e4"))
        c.attemptMove(from: sq("e7"), to: sq("e5"))
        XCTAssertEqual(c.moveHistory.count, 2)
        c.undo()
        XCTAssertEqual(c.moveHistory.count, 1)
        XCTAssertEqual(c.sideToMove, .black)
        XCTAssertNil(c.piece(at: sq("e5")))  // Black's e5 is undone
        XCTAssertEqual(c.piece(at: sq("e4")), Piece(color: .white, kind: .pawn)) // White's e4 remains
        c.undo()
        XCTAssertNil(c.piece(at: sq("e4")))
        XCTAssertEqual(c.sideToMove, .white)
        XCTAssertTrue(c.moveHistory.isEmpty)
    }

    func testSANHistoryTracksMoves() {
        let c = GameController()
        c.attemptMove(from: sq("e2"), to: sq("e4"))
        c.attemptMove(from: sq("e7"), to: sq("e5"))
        c.attemptMove(from: sq("g1"), to: sq("f3"))
        c.attemptMove(from: sq("b8"), to: sq("c6"))
        XCTAssertEqual(c.sanHistory, ["e4", "e5", "Nf3", "Nc6"])
        XCTAssertEqual(c.figurineHistory, ["e4", "e5", "♞f3", "♞c6"])

        c.undo()
        XCTAssertEqual(c.sanHistory, ["e4", "e5", "Nf3"])
        XCTAssertEqual(c.figurineHistory, ["e4", "e5", "♞f3"])

        c.reset()
        XCTAssertTrue(c.sanHistory.isEmpty)
        XCTAssertTrue(c.figurineHistory.isEmpty)
    }

    func testStatusText() {
        let c = GameController()
        XCTAssertEqual(c.statusText, "White to move")
        c.load(fen: "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")
        XCTAssertEqual(c.statusText, "Checkmate — Black wins")
    }
}
