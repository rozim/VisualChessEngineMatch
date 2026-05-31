import XCTest

final class MoveGenerationTests: XCTestCase {

    private func sq(_ text: String) -> Square {
        let c = Array(text)
        return Square(file: Int(c[0].asciiValue! - Character("a").asciiValue!),
                      rank: Int(String(c[1]))! - 1)
    }

    // MARK: - Perft (the definitive move-generator correctness check)

    func testPerftStartPosition() {
        let g = GameState.standard
        XCTAssertEqual(g.perft(1), 20)
        XCTAssertEqual(g.perft(2), 400)
        XCTAssertEqual(g.perft(3), 8902)
        XCTAssertEqual(g.perft(4), 197281)
    }

    func testPerftKiwipete() {
        // The classic "Kiwipete" position: castling, en passant, pins, promotions.
        let g = GameState(fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")!
        XCTAssertEqual(g.perft(1), 48)
        XCTAssertEqual(g.perft(2), 2039)
        XCTAssertEqual(g.perft(3), 97862)
    }

    func testPerftEndgamePosition() {
        // Perft position 3 from the Chess Programming Wiki.
        let g = GameState(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")!
        XCTAssertEqual(g.perft(1), 14)
        XCTAssertEqual(g.perft(2), 191)
        XCTAssertEqual(g.perft(3), 2812)
        XCTAssertEqual(g.perft(4), 43238)
    }

    // MARK: - Targeted rules

    func testPinnedKnightHasNoMoves() {
        // White knight on e2 is pinned to the white king by the black rook on e8.
        let g = GameState(fen: "4r2k/8/8/8/8/8/4N3/4K3 w - - 0 1")!
        XCTAssertTrue(g.legalMoves(from: sq("e2")).isEmpty)
    }

    func testEnPassantCaptureRemovesPawn() {
        // White pawn d5, black pawn c5, en-passant target c6.
        let g = GameState(fen: "4k3/8/8/2pP4/8/8/8/4K3 w - c6 0 1")!
        let ep = Move(from: sq("d5"), to: sq("c6"))
        XCTAssertTrue(g.legalMoves(from: sq("d5")).contains(ep))

        let after = g.make(ep)
        XCTAssertEqual(after.piece(at: sq("c6")), Piece(color: .white, kind: .pawn))
        XCTAssertNil(after.piece(at: sq("c5")))  // the captured pawn is gone
        XCTAssertNil(after.piece(at: sq("d5")))
    }

    func testCastlingBothSides() {
        let g = GameState(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")!
        let kingside = Move(from: sq("e1"), to: sq("g1"))
        let queenside = Move(from: sq("e1"), to: sq("c1"))
        let moves = g.legalMoves(from: sq("e1"))
        XCTAssertTrue(moves.contains(kingside))
        XCTAssertTrue(moves.contains(queenside))

        let after = g.make(kingside)
        XCTAssertEqual(after.piece(at: sq("g1")), Piece(color: .white, kind: .king))
        XCTAssertEqual(after.piece(at: sq("f1")), Piece(color: .white, kind: .rook))
        XCTAssertNil(after.piece(at: sq("h1")))
    }

    func testCannotCastleThroughAttackedSquare() {
        // Black rook on f8 attacks f1, so White may not castle kingside.
        let g = GameState(fen: "r4rk1/8/8/8/8/8/8/R3K2R w KQ - 0 1")!
        XCTAssertFalse(g.legalMoves(from: sq("e1")).contains(Move(from: sq("e1"), to: sq("g1"))))
        // Queenside is still available.
        XCTAssertTrue(g.legalMoves(from: sq("e1")).contains(Move(from: sq("e1"), to: sq("c1"))))
    }

    func testPromotionGeneratesFourMoves() {
        let g = GameState(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")!
        let moves = g.legalMoves(from: sq("a7"))
        XCTAssertEqual(Set(moves.map { $0.promotion }), [.queen, .rook, .bishop, .knight])
        XCTAssertTrue(moves.allSatisfy { $0.to == sq("a8") })
    }

    func testFoolsMateIsCheckmate() {
        let g = GameState(fen: "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")!
        XCTAssertTrue(g.isInCheck(.white))
        XCTAssertTrue(g.legalMoves().isEmpty)
        XCTAssertTrue(g.isCheckmate)
        XCTAssertFalse(g.isStalemate)
    }

    func testStalemate() {
        // Black king a8, white queen c7, white king c8-ish: classic stalemate.
        let g = GameState(fen: "k7/2Q5/1K6/8/8/8/8/8 b - - 0 1")!
        XCTAssertFalse(g.isInCheck(.black))
        XCTAssertTrue(g.legalMoves().isEmpty)
        XCTAssertTrue(g.isStalemate)
        XCTAssertFalse(g.isCheckmate)
    }

    func testFENRoundTrip() {
        let fens = [
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
            "4k3/8/8/2pP4/8/8/8/4K3 w - c6 0 1",
        ]
        for fen in fens {
            XCTAssertEqual(GameState(fen: fen)?.fen(), fen, "round trip failed for \(fen)")
        }
    }

    func testRejectsInvalidFEN() {
        XCTAssertNil(GameState(fen: "not a fen"))
        XCTAssertNil(GameState(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1")) // 7 ranks
    }
}
