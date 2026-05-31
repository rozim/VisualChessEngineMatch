import Foundation

/// Configuration for a single chess engine in a match.
struct EngineConfig: Equatable, Codable {
    /// Friendly name for the engine (e.g. "Stockfish 16").
    var name: String
    /// Full path to the engine binary.
    var binaryPath: String
    /// Time control: total time per game in seconds.
    var timePerGame: TimeInterval
    /// Time control: increment per move in seconds.
    var incrementPerMove: TimeInterval
    /// Custom UCI option overrides (option name -> value string).
    var uciOptions: [String: String]

    static let defaultStockfishPath = "/usr/local/bin/stockfish"

    static func standard(name: String) -> EngineConfig {
        EngineConfig(
            name: name,
            binaryPath: defaultStockfishPath,
            timePerGame: 10,
            incrementPerMove: 0.1,
            uciOptions: [:]
        )
    }
}

/// Configuration for a full match between two engines.
struct MatchConfig: Equatable, Codable {
    /// Number of mini-matches to play (each mini-match is 2 games, swapping colors).
    var miniMatchCount: Int
    /// Path to the EPD file containing starting positions.
    var epdFilePath: String?
    /// Path where the PGN log of the match should be written.
    var pgnLogPath: String?
    /// Configuration for engine 1.
    var engine1: EngineConfig
    /// Configuration for engine 2.
    var engine2: EngineConfig

    static func standard() -> MatchConfig {
        MatchConfig(
            miniMatchCount: 10,
            epdFilePath: nil,
            pgnLogPath: nil,
            engine1: .standard(name: "Engine 1"),
            engine2: .standard(name: "Engine 2")
        )
    }
}
