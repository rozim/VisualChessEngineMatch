import XCTest

final class SquareTests: XCTestCase {

    func testCornerSquareColors() {
        // The well-known rule: a1 is dark, h1 is light, a8 is light, h8 is dark.
        XCTAssertEqual(Square(file: 0, rank: 0).color, .dark)  // a1
        XCTAssertEqual(Square(file: 7, rank: 0).color, .light) // h1
        XCTAssertEqual(Square(file: 0, rank: 7).color, .light) // a8
        XCTAssertEqual(Square(file: 7, rank: 7).color, .dark)  // h8
    }

    func testColorsAlternate() {
        // Every square differs in color from its horizontal neighbor.
        for rank in 0..<8 {
            for file in 0..<7 {
                XCTAssertNotEqual(
                    Square(file: file, rank: rank).color,
                    Square(file: file + 1, rank: rank).color,
                    "squares \(file),\(rank) and \(file + 1),\(rank) should differ"
                )
            }
        }
    }

    func testColorCounts() {
        // A chess board has exactly 32 light and 32 dark squares.
        var light = 0
        var dark = 0
        for rank in 0..<8 {
            for file in 0..<8 {
                switch Square(file: file, rank: rank).color {
                case .light: light += 1
                case .dark: dark += 1
                }
            }
        }
        XCTAssertEqual(light, 32)
        XCTAssertEqual(dark, 32)
    }

    func testAlgebraicNotation() {
        XCTAssertEqual(Square(file: 0, rank: 0).algebraic, "a1")
        XCTAssertEqual(Square(file: 4, rank: 3).algebraic, "e4")
        XCTAssertEqual(Square(file: 7, rank: 7).algebraic, "h8")
    }

    func testFileLetterAndRankNumber() {
        let e4 = Square(file: 4, rank: 3)
        XCTAssertEqual(e4.fileLetter, "e")
        XCTAssertEqual(e4.rankNumber, 4)
    }
}
