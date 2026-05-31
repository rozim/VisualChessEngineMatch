import Foundation

/// Helper for generating and saving PGN (Portable Game Notation) files.
struct PGNLogger {
    struct GameInfo {
        var event: String = "Engine Match"
        var site: String = "VisualChessEngineMatch"
        var date: String = "" // YYYY.MM.DD
        var round: String = "1"
        var white: String
        var black: String
        var result: String // "1-0", "0-1", or "1/2-1/2"
        var fen: String? // Optional starting position if not standard
        var moves: [String] // SAN moves
    }

    static func generatePGN(info: GameInfo) -> String {
        var pgn = ""
        
        let date = info.date.isEmpty ? currentDate() : info.date
        
        pgn += "[Event \"\(info.event)\"]\n"
        pgn += "[Site \"\(info.site)\"]\n"
        pgn += "[Date \"\(date)\"]\n"
        pgn += "[Round \"\(info.round)\"]\n"
        pgn += "[White \"\(info.white)\"]\n"
        pgn += "[Black \"\(info.black)\"]\n"
        pgn += "[Result \"\(info.result)\"]\n"
        
        if let fen = info.fen, fen != GameState.standard.fen() {
            pgn += "[SetUp \"1\"]\n"
            pgn += "[FEN \"\(fen)\"]\n"
        }
        
        pgn += "\n"
        
        // Moves.
        for i in stride(from: 0, to: info.moves.count, by: 2) {
            let moveNumber = (i / 2) + 1
            pgn += "\(moveNumber). \(info.moves[i])"
            if i + 1 < info.moves.count {
                pgn += " \(info.moves[i + 1]) "
            } else {
                pgn += " "
            }
        }
        
        pgn += info.result + "\n\n"
        return pgn
    }

    static func appendToLog(pgn: String, filePath: String) throws {
        let url = URL(fileURLWithPath: filePath)
        if !FileManager.default.fileExists(atPath: filePath) {
            try pgn.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            if let data = pgn.data(using: .utf8) {
                try handle.write(contentsOf: data)
                try handle.synchronize()
            }
        }
    }

    private static func currentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: Date())
    }
}
