import Foundation

/// Helper for loading and selecting positions from an EPD (Extended Position Description) file.
struct EPDFile {
    /// Loads all valid FEN positions from the given file.
    /// Lines starting with # or empty lines are ignored.
    /// Each line is treated as an EPD string; only the FEN-compatible part is extracted.
    static func load(path: String) throws -> [String] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return parse(content: content)
    }

    /// Loads the bundled openings.epd file.
    static func loadBundled() -> [String] {
        guard let url = Bundle.main.url(forResource: "openings", withExtension: "epd"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parse(content: content)
    }

    /// Parses EPD content into a list of FEN strings.
    static func parse(content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var positions: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // EPD lines often have extra fields after the FEN (separated by ; or just space).
            // FEN has exactly 6 fields. EPD is basically FEN with extra opcodes.
            // We'll take the first 4 fields (placement, side, castling, en passant)
            // and append "0 1" for halfmove/fullmove if missing.
            let parts = trimmed.components(separatedBy: .whitespaces)
            if parts.count >= 4 {
                let fen = parts.prefix(4).joined(separator: " ") + " 0 1"
                positions.append(fen)
            }
        }

        return positions
    }

    /// Selects `count` unique random positions from the list.
    /// If count > available, returns all available positions shuffled.
    static func selectUniqueRandom(from positions: [String], count: Int) -> [String] {
        var shuffled = positions.shuffled()
        return Array(shuffled.prefix(count))
    }
}
