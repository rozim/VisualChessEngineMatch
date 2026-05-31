import XCTest

final class UCIProtocolTests: XCTestCase {

    // MARK: id

    func testParseIDName() {
        let id = UCIProtocol.parseID("id name Stockfish 16.1")
        XCTAssertEqual(id?.0, .name)
        XCTAssertEqual(id?.1, "Stockfish 16.1")
    }

    func testParseIDAuthor() {
        let id = UCIProtocol.parseID("id author The Stockfish developers")
        XCTAssertEqual(id?.0, .author)
        XCTAssertEqual(id?.1, "The Stockfish developers")
    }

    func testParseIDRejectsOther() {
        XCTAssertNil(UCIProtocol.parseID("uciok"))
        XCTAssertNil(UCIProtocol.parseID("id something else"))
    }

    // MARK: option

    func testParseSpinOption() {
        let opt = UCIProtocol.parseOption("option name Hash type spin default 16 min 1 max 33554432")
        XCTAssertEqual(opt?.name, "Hash")
        XCTAssertEqual(opt?.type, .spin)
        XCTAssertEqual(opt?.defaultValue, "16")
        XCTAssertEqual(opt?.min, 1)
        XCTAssertEqual(opt?.max, 33554432)
    }

    func testParseCheckOption() {
        let opt = UCIProtocol.parseOption("option name Ponder type check default false")
        XCTAssertEqual(opt?.name, "Ponder")
        XCTAssertEqual(opt?.type, .check)
        XCTAssertEqual(opt?.defaultValue, "false")
    }

    func testParseComboOptionWithVars() {
        let opt = UCIProtocol.parseOption(
            "option name Style type combo default Normal var Solid var Normal var Risky")
        XCTAssertEqual(opt?.type, .combo)
        XCTAssertEqual(opt?.defaultValue, "Normal")
        XCTAssertEqual(opt?.vars, ["Solid", "Normal", "Risky"])
    }

    func testParseOptionWithSpacesInName() {
        // The name spans multiple tokens up to "type".
        let opt = UCIProtocol.parseOption("option name Clear Hash type button")
        XCTAssertEqual(opt?.name, "Clear Hash")
        XCTAssertEqual(opt?.type, .button)
    }

    func testParseStringOptionWithSpacedDefault() {
        let opt = UCIProtocol.parseOption(
            "option name SyzygyPath type string default /tmp/my tables")
        XCTAssertEqual(opt?.type, .string)
        XCTAssertEqual(opt?.defaultValue, "/tmp/my tables")
    }

    func testParseOptionRejectsNonOption() {
        XCTAssertNil(UCIProtocol.parseOption("readyok"))
    }

    // MARK: info

    func testParseInfoCentipawnsAndPV() {
        let info = UCIProtocol.parseInfo(
            "info depth 20 seldepth 28 multipv 1 score cp 34 nodes 1000000 nps 2000000 time 500 pv e2e4 e7e5 g1f3")
        XCTAssertEqual(info?.depth, 20)
        XCTAssertEqual(info?.selDepth, 28)
        XCTAssertEqual(info?.scoreCentipawns, 34)
        XCTAssertNil(info?.scoreMate)
        XCTAssertEqual(info?.nodes, 1000000)
        XCTAssertEqual(info?.nps, 2000000)
        XCTAssertEqual(info?.timeMillis, 500)
        XCTAssertEqual(info?.pv, ["e2e4", "e7e5", "g1f3"])
    }

    func testParseInfoMate() {
        let info = UCIProtocol.parseInfo("info depth 10 score mate 3 pv d1h5 g6h5 e2e4")
        XCTAssertEqual(info?.scoreMate, 3)
        XCTAssertNil(info?.scoreCentipawns)
    }

    func testParseInfoStringIsIgnored() {
        XCTAssertNil(UCIProtocol.parseInfo("info string NNUE evaluation using nn-xxxx.nnue"))
    }

    func testScoreTextOrientation() {
        var info = UCIInfo()
        info.scoreCentipawns = 50
        // +0.50 for White when it's White to move; flips for Black to move.
        XCTAssertEqual(info.scoreText(sideToMove: .white), "+0.50")
        XCTAssertEqual(info.scoreText(sideToMove: .black), "-0.50")

        var mateInfo = UCIInfo()
        mateInfo.scoreMate = 2
        XCTAssertEqual(mateInfo.scoreText(sideToMove: .white), "#2")
        XCTAssertEqual(mateInfo.scoreText(sideToMove: .black), "#-2")
    }

    // MARK: bestmove

    func testParseBestMove() {
        XCTAssertEqual(UCIProtocol.parseBestMove("bestmove e2e4 ponder e7e5"), "e2e4")
        XCTAssertEqual(UCIProtocol.parseBestMove("bestmove a7a8q"), "a7a8q")
        XCTAssertNil(UCIProtocol.parseBestMove("info depth 1"))
    }
}
