import Foundation

/// A snapshot of which piece (if any) occupies each square of the board.
///
/// Only piece placement is modelled here; side-to-move, castling rights, etc.
/// belong to later steps. Storage is indexed `[rank][file]`, both 0...7.
public struct Position: Equatable {
    private var pieces: [[Piece?]]

    /// Creates a position from an 8x8 grid of optional pieces, indexed
    /// `pieces[rank][file]` with rank 0 = rank 1 (White's back rank).
    public init(pieces: [[Piece?]]) {
        precondition(pieces.count == 8 && pieces.allSatisfy { $0.count == 8 },
                     "a position must be an 8x8 grid")
        self.pieces = pieces
    }

    /// The piece on `square`, or `nil` if the square is empty.
    public func piece(at square: Square) -> Piece? {
        pieces[square.rank][square.file]
    }

    /// An empty board.
    public static var empty: Position {
        Position(pieces: Array(repeating: Array(repeating: nil, count: 8), count: 8))
    }

    /// The piece-placement field of a FEN string (ranks 8 down to 1, '/'
    /// separated, digits for runs of empty squares), e.g. for the start
    /// position: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR".
    public var fenPlacement: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var emptyRun = 0
            for file in 0..<8 {
                if let piece = piece(at: Square(file: file, rank: rank)) {
                    if emptyRun > 0 { row += String(emptyRun); emptyRun = 0 }
                    row.append(piece.fenCharacter)
                } else {
                    emptyRun += 1
                }
            }
            if emptyRun > 0 { row += String(emptyRun) }
            rows.append(row)
        }
        return rows.joined(separator: "/")
    }

    /// A full FEN string for this position. Only piece placement is modelled
    /// here, so the remaining fields take the given defaults (which describe the
    /// standard start position when used with `.standard`).
    public func fen(sideToMove: PieceColor = .white,
                    castling: String = "KQkq",
                    enPassant: String = "-",
                    halfmoveClock: Int = 0,
                    fullmoveNumber: Int = 1) -> String {
        "\(fenPlacement) \(sideToMove.rawValue) \(castling) \(enPassant) \(halfmoveClock) \(fullmoveNumber)"
    }

    /// The standard chess starting position.
    public static var standard: Position {
        // File order a...h for the back rank.
        let backRank: [PieceKind] = [.rook, .knight, .bishop, .queen,
                                     .king, .bishop, .knight, .rook]
        var rows = Array(repeating: Array<Piece?>(repeating: nil, count: 8), count: 8)
        for file in 0..<8 {
            rows[0][file] = Piece(color: .white, kind: backRank[file]) // rank 1
            rows[1][file] = Piece(color: .white, kind: .pawn)          // rank 2
            rows[6][file] = Piece(color: .black, kind: .pawn)          // rank 7
            rows[7][file] = Piece(color: .black, kind: backRank[file]) // rank 8
        }
        return Position(pieces: rows)
    }
}
