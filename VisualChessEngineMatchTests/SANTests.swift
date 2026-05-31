import XCTest

final class SANTests: XCTestCase {

    private func sq(_ text: String) -> Square {
        let c = Array(text)
        return Square(file: Int(c[0].asciiValue! - Character("a").asciiValue!),
                      rank: Int(String(c[1]))! - 1)
    }

    // MARK: - UCI move parsing

    func testParseUCIMove() {
        XCTAssertEqual(Move(uci: "e2e4"), Move(from: sq("e2"), to: sq("e4")))
        XCTAssertEqual(Move(uci: "e7e8q"), Move(from: sq("e7"), to: sq("e8"), promotion: .queen))
        XCTAssertEqual(Move(uci: "e1g1"), Move(from: sq("e1"), to: sq("g1")))
        XCTAssertNil(Move(uci: "e2"))
        XCTAssertNil(Move(uci: "e2e9"))
        XCTAssertNil(Move(uci: "z2e4"))
        XCTAssertNil(Move(uci: "e7e8k")) // can't promote to king
    }

    // MARK: - Single-move SAN

    func testBasicPawnAndPieceMoves() {
        let g = GameState.standard
        XCTAssertEqual(g.san(for: Move(uci: "e2e4")!), "e4")
        XCTAssertEqual(g.san(for: Move(uci: "g1f3")!), "Nf3")
        XCTAssertEqual(g.san(for: Move(uci: "b1c3")!), "Nc3")
    }

    func testCaptures() {
        // White pawn d4 takes e5; knight recaptures.
        let g = GameState(fen: "rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq e6 0 2")!
        XCTAssertEqual(g.san(for: Move(uci: "d4e5")!), "dxe5")
    }

    func testKnightCaptureNotation() {
        let g = GameState(fen: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")!
        XCTAssertEqual(g.san(for: Move(uci: "f3e5")!), "Nxe5")
    }

    func testCastlingSAN() {
        let g = GameState(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")!
        XCTAssertEqual(g.san(for: Move(uci: "e1g1")!), "O-O")
        XCTAssertEqual(g.san(for: Move(uci: "e1c1")!), "O-O-O")
    }

    func testPromotionWithCheck() {
        // a7-a8=Q delivers check to the black king on e8 along the 8th rank.
        let g = GameState(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")!
        XCTAssertEqual(g.san(for: Move(uci: "a7a8q")!), "a8=Q+")
        XCTAssertEqual(g.san(for: Move(uci: "a7a8n")!), "a8=N")
    }

    func testFileDisambiguation() {
        // Two white knights (c3 and g1) can both reach e2.
        let g = GameState(fen: "4k3/8/8/8/8/2N5/8/4K1N1 w - - 0 1")!
        XCTAssertEqual(g.san(for: Move(uci: "c3e2")!), "Nce2")
        XCTAssertEqual(g.san(for: Move(uci: "g1e2")!), "Nge2")
    }

    func testRankDisambiguation() {
        // Two white rooks on a1 and a5 can both reach a3 (same file -> use rank).
        let g = GameState(fen: "4k3/8/8/R7/8/8/8/R3K3 w - - 0 1")!
        XCTAssertEqual(g.san(for: Move(uci: "a1a3")!), "R1a3")
        XCTAssertEqual(g.san(for: Move(uci: "a5a3")!), "R5a3")
    }

    func testCheckmateSuffix() {
        // Back-rank mate: Ra8#.
        let g = GameState(fen: "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")!
        XCTAssertEqual(g.san(for: Move(uci: "a1a8")!), "Ra8#")
    }

    // MARK: - Figurine SAN

    func testFigurineSAN() {
        let g = GameState.standard
        XCTAssertEqual(g.san(for: Move(uci: "g1f3")!, figurine: true), "♞f3")
        XCTAssertEqual(g.san(for: Move(uci: "e2e4")!, figurine: true), "e4") // pawns have no letter in SAN usually

        // Promotion to Queen with figurine
        let promo = GameState(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")!
        XCTAssertEqual(promo.san(for: Move(uci: "a7a8q")!, figurine: true), "a8=♛+")
    }

    func testFigurineSANLine() {
        let pv = ["d2d4", "d7d5", "c2c4", "e7e6", "b1c3", "g8f6"]
        let san = GameState.standard.sanLine(forUCIMoves: pv, figurine: true)
        XCTAssertEqual(san, ["d4", "d5", "c4", "e6", "♞c3", "♞f6"])
    }

    // MARK: - PV conversion

    func testPVLineToSAN() {
        // The opening prefix of the example PV from CLAUDE.md, from the start.
        let pv = ["d2d4", "d7d5", "c2c4", "e7e6", "b1c3", "g8f6",
                  "c4d5", "e6d5", "c1g5", "f8e7", "e2e3", "e8g8"]
        let san = GameState.standard.sanLine(forUCIMoves: pv)
        XCTAssertEqual(san, ["d4", "d5", "c4", "e6", "Nc3", "Nf6",
                             "cxd5", "exd5", "Bg5", "Be7", "e3", "O-O"])
    }

    func testFullExamplePVConvertsCompletely() {
        // The entire PV from CLAUDE.md must convert without dropping moves.
        let pv = "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c4d5 e6d5 c1g5 f8e7 e2e3 e8g8 f1d3 f8e8 g1f3 h7h6 g5f4 c7c5 e1g1 c5c4 d3c2 b8c6 c3b5 e8f8 h2h3 a7a6 b5c3 e7d6 f3e5 d8c7 e5c6 d6f4 c6b4 c7a5 c3d5 f6d5 b4d5 a5d5 e3f4 f8d8 f1e1 c8e6 e1e4 e6f5 e4e5 f5c2 e5d5 c2d1 d5d8 a8d8 a1d1".split(separator: " ").map(String.init)
        let san = GameState.standard.sanLine(forUCIMoves: pv)
        XCTAssertEqual(san.count, pv.count, "every PV move should convert to SAN")
        XCTAssertEqual(san.prefix(6), ["d4", "d5", "c4", "e6", "Nc3", "Nf6"])
    }
}
