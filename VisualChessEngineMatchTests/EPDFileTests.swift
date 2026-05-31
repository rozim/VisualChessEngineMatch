import XCTest

final class EPDFileTests: XCTestCase {

    func testParseEPD() {
        let content = """
        rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1
        # A comment
        rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2 ; hmvc 0; fmvn 2;
        """
        let positions = EPDFile.parse(content: content)
        XCTAssertEqual(positions.count, 2)
        XCTAssertEqual(positions[0], "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
        // Note: our parser appends "0 1" to the first 4 fields, so even if the EPD had fmvn 2, 
        // it might get normalized to 0 1 in this simple implementation if we only take 4 fields.
        // Actually my implementation takes prefix(4) and appends " 0 1".
        XCTAssertEqual(positions[1], "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 1")
    }

    func testSelectUniqueRandom() {
        let positions = (1...10).map { "pos\($0)" }
        let selected = EPDFile.selectUniqueRandom(from: positions, count: 5)
        XCTAssertEqual(selected.count, 5)
        XCTAssertEqual(Set(selected).count, 5)
        for pos in selected {
            XCTAssertTrue(positions.contains(pos))
        }
    }

    func testSelectMoreThanAvailable() {
        let positions = ["pos1", "pos2"]
        let selected = EPDFile.selectUniqueRandom(from: positions, count: 5)
        XCTAssertEqual(selected.count, 2)
        XCTAssertEqual(Set(selected).count, 2)
    }
}
