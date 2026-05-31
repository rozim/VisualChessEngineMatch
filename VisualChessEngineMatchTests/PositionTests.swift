import XCTest

final class PositionTests: XCTestCase {

    private func square(_ text: String) -> Square {
        let chars = Array(text)
        let file = Int(chars[0].asciiValue! - Character("a").asciiValue!)
        let rank = Int(String(chars[1]))! - 1
        return Square(file: file, rank: rank)
    }

    func testStartingPositionPieceCounts() {
        let p = Position.standard
        var counts: [Piece: Int] = [:]
        for rank in 0..<8 {
            for file in 0..<8 {
                if let piece = p.piece(at: Square(file: file, rank: rank)) {
                    counts[piece, default: 0] += 1
                }
            }
        }
        for color in PieceColor.allCases {
            XCTAssertEqual(counts[Piece(color: color, kind: .pawn)], 8)
            XCTAssertEqual(counts[Piece(color: color, kind: .rook)], 2)
            XCTAssertEqual(counts[Piece(color: color, kind: .knight)], 2)
            XCTAssertEqual(counts[Piece(color: color, kind: .bishop)], 2)
            XCTAssertEqual(counts[Piece(color: color, kind: .queen)], 1)
            XCTAssertEqual(counts[Piece(color: color, kind: .king)], 1)
        }
        // 32 pieces on 64 squares.
        XCTAssertEqual(counts.values.reduce(0, +), 32)
    }

    func testEmptyMiddleRanks() {
        let p = Position.standard
        for rank in 2...5 {
            for file in 0..<8 {
                XCTAssertNil(p.piece(at: Square(file: file, rank: rank)))
            }
        }
    }

    func testKeySquares() {
        let p = Position.standard
        XCTAssertEqual(p.piece(at: square("e1")), Piece(color: .white, kind: .king))
        XCTAssertEqual(p.piece(at: square("d1")), Piece(color: .white, kind: .queen))
        XCTAssertEqual(p.piece(at: square("a1")), Piece(color: .white, kind: .rook))
        XCTAssertEqual(p.piece(at: square("h1")), Piece(color: .white, kind: .rook))
        XCTAssertEqual(p.piece(at: square("b1")), Piece(color: .white, kind: .knight))
        XCTAssertEqual(p.piece(at: square("c1")), Piece(color: .white, kind: .bishop))
        XCTAssertEqual(p.piece(at: square("e2")), Piece(color: .white, kind: .pawn))

        XCTAssertEqual(p.piece(at: square("e8")), Piece(color: .black, kind: .king))
        XCTAssertEqual(p.piece(at: square("d8")), Piece(color: .black, kind: .queen))
        XCTAssertEqual(p.piece(at: square("e7")), Piece(color: .black, kind: .pawn))
    }

    func testAssetNames() {
        XCTAssertEqual(Piece(color: .white, kind: .king).assetName, "wK")
        XCTAssertEqual(Piece(color: .black, kind: .pawn).assetName, "bP")
        XCTAssertEqual(Piece(color: .white, kind: .knight).assetName, "wN")
    }

    func testStartingPositionFENPlacement() {
        XCTAssertEqual(Position.standard.fenPlacement,
                       "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR")
    }

    func testStartingPositionFullFEN() {
        XCTAssertEqual(Position.standard.fen(),
                       "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    }

    func testEmptyBoardFEN() {
        XCTAssertEqual(Position.empty.fenPlacement, "8/8/8/8/8/8/8/8")
    }

    func testFenCharacters() {
        XCTAssertEqual(Piece(color: .white, kind: .knight).fenCharacter, "N")
        XCTAssertEqual(Piece(color: .black, kind: .knight).fenCharacter, "n")
        XCTAssertEqual(Piece(color: .white, kind: .pawn).fenCharacter, "P")
        XCTAssertEqual(Piece(color: .black, kind: .king).fenCharacter, "k")
    }
}
