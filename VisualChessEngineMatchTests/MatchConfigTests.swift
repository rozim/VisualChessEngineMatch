import XCTest

final class MatchConfigTests: XCTestCase {

    func testStandardConfigDefaults() {
        let config = MatchConfig.standard()
        XCTAssertEqual(config.miniMatchCount, 10)
        XCTAssertNil(config.epdFilePath)
        XCTAssertEqual(config.pgnLogPath, "match.pgn")

        XCTAssertEqual(config.engine1.name, "Engine 1")
        XCTAssertEqual(config.engine1.binaryPath, "/usr/local/bin/stockfish")
        XCTAssertEqual(config.engine1.timePerGame, 10)
        XCTAssertEqual(config.engine1.incrementPerMove, 0.1)
        XCTAssertTrue(config.engine1.uciOptions.isEmpty)

        XCTAssertEqual(config.engine2.name, "Engine 2")
    }

    func testCodableRoundTrip() throws {
        var config = MatchConfig.standard()
        config.miniMatchCount = 20
        config.engine1.uciOptions["Threads"] = "4"
        config.epdFilePath = "/tmp/test.epd"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MatchConfig.self, from: data)

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.engine1.uciOptions["Threads"], "4")
    }
}
