import Foundation

extension Move {
    /// Parses a UCI long-algebraic move such as "e2e4", "e1g1" (castling), or
    /// "e7e8q" (promotion). Returns nil if the string is malformed.
    public init?(uci: String) {
        let chars = Array(uci)
        guard chars.count == 4 || chars.count == 5 else { return nil }

        func file(_ c: Character) -> Int? {
            guard let v = c.asciiValue, (97...104).contains(Int(v)) else { return nil }
            return Int(v) - 97
        }
        func rank(_ c: Character) -> Int? {
            guard let v = c.wholeNumberValue, (1...8).contains(v) else { return nil }
            return v - 1
        }
        guard let ff = file(chars[0]), let fr = rank(chars[1]),
              let tf = file(chars[2]), let tr = rank(chars[3]) else { return nil }

        var promotion: PieceKind?
        if chars.count == 5 {
            guard let kind = PieceKind(rawValue: String(chars[4]).uppercased()),
                  [.queen, .rook, .bishop, .knight].contains(kind) else { return nil }
            promotion = kind
        }
        self.init(from: Square(file: ff, rank: fr),
                  to: Square(file: tf, rank: tr),
                  promotion: promotion)
    }
}

extension GameState {

    /// Standard Algebraic Notation for `move`, which must be legal in this
    /// position (returns nil otherwise). Handles captures, disambiguation,
    /// castling, promotion, en passant, and check/checkmate suffixes.
    /// If `figurine` is true, piece letters are replaced by unicode glyphs.
    public func san(for move: Move, figurine: Bool = false) -> String? {
        guard let mover = piece(at: move.from), mover.color == sideToMove else { return nil }
        let legal = legalMoves()
        guard legal.contains(move) else { return nil }

        let suffix = checkSuffix(after: make(move))

        // Castling.
        if mover.kind == .king, abs(move.to.file - move.from.file) == 2 {
            return (move.to.file == 6 ? "O-O" : "O-O-O") + suffix
        }

        // A pawn capture changes file (covers en passant, where the target is empty).
        let isCapture = piece(at: move.to) != nil
            || (mover.kind == .pawn && move.from.file != move.to.file)

        var san = ""
        if mover.kind == .pawn {
            if isCapture { san += String(move.from.fileLetter) + "x" }
            san += move.to.algebraic
            if let promotion = move.promotion {
                san += "="
                san += figurine ? promotion.figurine : promotion.rawValue
            }
        } else {
            san += figurine ? mover.kind.figurine : mover.kind.rawValue
            san += disambiguation(for: move, piece: mover, legal: legal)
            if isCapture { san += "x" }
            san += move.to.algebraic
        }
        return san + suffix
    }

    /// Converts a sequence of UCI moves (e.g. an engine PV) to SAN, applying
    /// each move to advance the position. Stops at the first move that cannot
    /// be parsed or is illegal.
    public func sanLine(forUCIMoves ucis: [String], figurine: Bool = false) -> [String] {
        var result: [String] = []
        var state = self
        for uci in ucis {
            guard let move = Move(uci: uci), let san = state.san(for: move, figurine: figurine) else { break }
            result.append(san)
            state = state.make(move)
        }
        return result
    }

    // MARK: - Helpers

    private func disambiguation(for move: Move, piece: Piece, legal: [Move]) -> String {
        let rivals = legal.filter { other in
            other.to == move.to && other.from != move.from
                && self.piece(at: other.from)?.kind == piece.kind
        }
        guard !rivals.isEmpty else { return "" }

        let sameFile = rivals.contains { $0.from.file == move.from.file }
        let sameRank = rivals.contains { $0.from.rank == move.from.rank }
        if !sameFile { return String(move.from.fileLetter) }
        if !sameRank { return String(move.from.rankNumber) }
        return move.from.algebraic
    }

    private func checkSuffix(after next: GameState) -> String {
        if next.isCheckmate { return "#" }
        if next.isInCheck(next.sideToMove) { return "+" }
        return ""
    }
}
