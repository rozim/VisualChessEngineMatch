import Foundation

enum MatchMode: String, Codable, CaseIterable {
    case time
    case nodes
}

/// Configuration for a single chess engine in a match.
struct EngineConfig: Equatable, Codable {
    /// Friendly name for the engine (e.g. "Stockfish 16").
    var name: String
    /// Full path to the engine binary.
    var binaryPath: String
    /// Time control: total time per game in seconds (Integer only per CLAUDE.md).
    var timePerGame: Int
    /// Time control: increment per move in seconds.
    var incrementPerMove: Double
    /// Node limit per move (default 10000 per CLAUDE.md).
    var nodeLimit: Int
    /// Custom UCI option overrides (option name -> value string).
    var uciOptions: [String: String]

    static let defaultStockfishPath = "/usr/local/bin/stockfish"
    static let defaultLc0Path = "/opt/homebrew/bin/lc0"

    static func standard(name: String) -> EngineConfig {
        EngineConfig(
            name: name,
            binaryPath: name.contains("1") ? defaultStockfishPath : defaultLc0Path,
            timePerGame: 10,
            incrementPerMove: 0.1,
            nodeLimit: 10000,
            uciOptions: [:]
        )
    }
}

/// Configuration for a full match between two engines.
struct MatchConfig: Equatable, Codable {
    /// Match mode (by time or by node limit).
    var mode: MatchMode
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

    static let userDefaultsKey = "VisualChessEngineMatch.MatchConfig"

    static func standard() -> MatchConfig {
        MatchConfig(
            mode: .time,
            miniMatchCount: 10,
            epdFilePath: nil,
            pgnLogPath: "match.pgn",
            engine1: .standard(name: "Engine 1"),
            engine2: .standard(name: "Engine 2")
        )
    }

    /// Persists the configuration to UserDefaults.
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }

    /// Loads the configuration from UserDefaults, or returns the standard default if none is found.
    static func load() -> MatchConfig {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(MatchConfig.self, from: data) {
            return decoded
        }
        return .standard()
    }
}
