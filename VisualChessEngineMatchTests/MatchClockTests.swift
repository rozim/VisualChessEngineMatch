import XCTest

final class MatchClockTests: XCTestCase {

    func testBasicClockConsumption() {
        var clock = MatchClock(whiteTime: 60, blackTime: 60)
        XCTAssertEqual(clock.whiteTime, 60)
        XCTAssertEqual(clock.blackTime, 60)

        clock.consume(elapsed: 5.5, for: .white)
        XCTAssertEqual(clock.whiteTime, 54.5)
        XCTAssertEqual(clock.blackTime, 60)

        clock.consume(elapsed: 10, for: .black)
        XCTAssertEqual(clock.whiteTime, 54.5)
        XCTAssertEqual(clock.blackTime, 50)
    }

    func testIncrements() {
        var clock = MatchClock(whiteTime: 10, blackTime: 10, whiteIncrement: 1.5, blackIncrement: 2.0)

        clock.consume(elapsed: 5, for: .white)
        clock.addIncrement(for: .white)
        XCTAssertEqual(clock.whiteTime, 6.5) // 10 - 5 + 1.5

        clock.consume(elapsed: 8, for: .black)
        clock.addIncrement(for: .black)
        XCTAssertEqual(clock.blackTime, 4.0) // 10 - 8 + 2.0
    }

    func testFlagFall() {
        var clock = MatchClock(whiteTime: 5, blackTime: 5)
        XCTAssertFalse(clock.hasFlagFallen(for: .white))

        clock.consume(elapsed: 5, for: .white)
        XCTAssertTrue(clock.hasFlagFallen(for: .white))
        XCTAssertEqual(clock.whiteTime, 0)

        clock.consume(elapsed: 1, for: .white) // Should not go negative
        XCTAssertEqual(clock.whiteTime, 0)
    }

    func testMsConversion() {
        let clock = MatchClock(whiteTime: 10.5, blackTime: 5, whiteIncrement: 0.1, blackIncrement: 0)
        XCTAssertEqual(clock.timeMs(for: .white), 10500)
        XCTAssertEqual(clock.timeMs(for: .black), 5000)
        XCTAssertEqual(clock.incMs(for: .white), 100)
        XCTAssertEqual(clock.incMs(for: .black), 0)
    }
}
