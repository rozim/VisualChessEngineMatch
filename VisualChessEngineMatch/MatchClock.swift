import Foundation

/// Manages the remaining time and increments for both players in a chess game.
struct MatchClock: Equatable {
    /// Remaining time for White in seconds.
    private(set) var whiteTime: TimeInterval
    /// Remaining time for Black in seconds.
    private(set) var blackTime: TimeInterval

    /// Increment for White in seconds.
    let whiteIncrement: TimeInterval
    /// Increment for Black in seconds.
    let blackIncrement: TimeInterval

    init(whiteTime: TimeInterval, blackTime: TimeInterval, whiteIncrement: TimeInterval = 0, blackIncrement: TimeInterval = 0) {
        self.whiteTime = whiteTime
        self.blackTime = blackTime
        self.whiteIncrement = whiteIncrement
        self.blackIncrement = blackIncrement
    }

    /// Decrements the time for the specified color.
    mutating func consume(elapsed: TimeInterval, for color: PieceColor) {
        switch color {
        case .white:
            whiteTime = max(0, whiteTime - elapsed)
        case .black:
            blackTime = max(0, blackTime - elapsed)
        }
    }

    /// Adds the increment for the specified color.
    mutating func addIncrement(for color: PieceColor) {
        switch color {
        case .white:
            whiteTime += whiteIncrement
        case .black:
            blackTime += blackIncrement
        }
    }

    /// Returns true if the specified color has run out of time.
    func hasFlagFallen(for color: PieceColor) -> Bool {
        switch color {
        case .white:
            return whiteTime <= 0
        case .black:
            return blackTime <= 0
        }
    }

    /// Time remaining for a specific color in milliseconds (as used in UCI "go").
    func timeMs(for color: PieceColor) -> Int {
        let time = color == .white ? whiteTime : blackTime
        return Int(time * 1000)
    }

    /// Increment for a specific color in milliseconds (as used in UCI "go").
    func incMs(for color: PieceColor) -> Int {
        let inc = color == .white ? whiteIncrement : blackIncrement
        return Int(inc * 1000)
    }
}
