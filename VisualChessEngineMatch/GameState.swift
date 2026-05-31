import Foundation

/// Castling availability for both sides.
public struct CastlingRights: OptionSet, Equatable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let whiteKingside  = CastlingRights(rawValue: 1 << 0)
    public static let whiteQueenside = CastlingRights(rawValue: 1 << 1)
    public static let blackKingside  = CastlingRights(rawValue: 1 << 2)
    public static let blackQueenside = CastlingRights(rawValue: 1 << 3)
    public static let all: CastlingRights = [.whiteKingside, .whiteQueenside, .blackKingside, .blackQueenside]

    /// The "KQkq" field of a FEN string (or "-" if no rights remain).
    public var fenField: String {
        var s = ""
        if contains(.whiteKingside)  { s += "K" }
        if contains(.whiteQueenside) { s += "Q" }
        if contains(.blackKingside)  { s += "k" }
        if contains(.blackQueenside) { s += "q" }
        return s.isEmpty ? "-" : s
    }
}

/// A complete chess game state: piece placement plus side to move, castling
/// rights, en-passant target, and the move clocks. Provides legal move
/// generation, legality testing, and move application.
///
/// Squares are stored in a flat 64-element array indexed `rank * 8 + file`.
public struct GameState: Equatable {
    public private(set) var squares: [Piece?]
    public var sideToMove: PieceColor
    public var castling: CastlingRights
    public var enPassant: Square?
    public var halfmoveClock: Int
    public var fullmoveNumber: Int

    public init(squares: [Piece?], sideToMove: PieceColor, castling: CastlingRights,
                enPassant: Square?, halfmoveClock: Int, fullmoveNumber: Int) {
        precondition(squares.count == 64, "board must have 64 squares")
        self.squares = squares
        self.sideToMove = sideToMove
        self.castling = castling
        self.enPassant = enPassant
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    // MARK: - Indexing

    @inline(__always) private func index(_ file: Int, _ rank: Int) -> Int { rank * 8 + file }
    @inline(__always) private func index(_ square: Square) -> Int { square.rank * 8 + square.file }
    @inline(__always) private func onBoard(_ file: Int, _ rank: Int) -> Bool {
        file >= 0 && file < 8 && rank >= 0 && rank < 8
    }

    public func piece(at square: Square) -> Piece? { squares[index(square)] }

    /// A placement-only `Position`, for the board view and FEN placement.
    public var position: Position {
        var rows = Array(repeating: Array<Piece?>(repeating: nil, count: 8), count: 8)
        for rank in 0..<8 {
            for file in 0..<8 {
                rows[rank][file] = squares[index(file, rank)]
            }
        }
        return Position(pieces: rows)
    }

    // MARK: - Standard / FEN

    public static var standard: GameState {
        // swiftlint:disable:next force_unwrapping
        GameState(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")!
    }

    /// A full FEN string for this state.
    public func fen() -> String {
        position.fen(sideToMove: sideToMove,
                     castling: castling.fenField,
                     enPassant: enPassant?.algebraic ?? "-",
                     halfmoveClock: halfmoveClock,
                     fullmoveNumber: fullmoveNumber)
    }

    /// Parses a FEN string. The last two fields (clocks) may be omitted.
    public init?(fen: String) {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard fields.count >= 4 else { return nil }

        // 1. Placement (ranks 8 down to 1).
        var squares = Array<Piece?>(repeating: nil, count: 64)
        let ranks = fields[0].split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else { return nil }
        for (rowIndex, rankString) in ranks.enumerated() {
            let rank = 7 - rowIndex
            var file = 0
            for ch in rankString {
                if let digit = ch.wholeNumberValue, ch.isNumber {
                    file += digit
                } else if let piece = Piece(fenCharacter: ch) {
                    guard file < 8 else { return nil }
                    squares[rank * 8 + file] = piece
                    file += 1
                } else {
                    return nil
                }
            }
            guard file == 8 else { return nil }
        }

        // 2. Side to move.
        guard let side = PieceColor(rawValue: fields[1]) else { return nil }

        // 3. Castling.
        var castling: CastlingRights = []
        if fields[2] != "-" {
            for ch in fields[2] {
                switch ch {
                case "K": castling.insert(.whiteKingside)
                case "Q": castling.insert(.whiteQueenside)
                case "k": castling.insert(.blackKingside)
                case "q": castling.insert(.blackQueenside)
                default: return nil
                }
            }
        }

        // 4. En passant target.
        var enPassant: Square?
        if fields[3] != "-" {
            let chars = Array(fields[3])
            guard chars.count == 2,
                  let fileVal = chars[0].asciiValue,
                  let rankVal = chars[1].wholeNumberValue,
                  (97...104).contains(Int(fileVal)),
                  (1...8).contains(rankVal) else { return nil }
            enPassant = Square(file: Int(fileVal) - 97, rank: rankVal - 1)
        }

        // 5 & 6. Clocks (optional).
        let halfmove = fields.count > 4 ? Int(fields[4]) ?? 0 : 0
        let fullmove = fields.count > 5 ? Int(fields[5]) ?? 1 : 1

        self.init(squares: squares, sideToMove: side, castling: castling,
                  enPassant: enPassant, halfmoveClock: halfmove, fullmoveNumber: fullmove)
    }

    // MARK: - Attack detection

    private static let knightOffsets = [(1, 2), (2, 1), (2, -1), (1, -2),
                                        (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let kingOffsets = [(1, 0), (1, 1), (0, 1), (-1, 1),
                                      (-1, 0), (-1, -1), (0, -1), (1, -1)]
    private static let bishopDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    private static let rookDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    /// Whether the square `(file, rank)` is attacked by any piece of `attacker`.
    public func isAttacked(file: Int, rank: Int, by attacker: PieceColor) -> Bool {
        // Pawns: an attacker pawn sits one rank toward its own side, on an
        // adjacent file. White pawns attack upward, so they sit one rank below.
        let pawnRank = attacker == .white ? rank - 1 : rank + 1
        for df in [-1, 1] {
            let f = file + df
            if onBoard(f, pawnRank), let p = squares[index(f, pawnRank)],
               p.color == attacker, p.kind == .pawn {
                return true
            }
        }
        // Knights.
        for (df, dr) in GameState.knightOffsets {
            let f = file + df, r = rank + dr
            if onBoard(f, r), let p = squares[index(f, r)], p.color == attacker, p.kind == .knight {
                return true
            }
        }
        // King.
        for (df, dr) in GameState.kingOffsets {
            let f = file + df, r = rank + dr
            if onBoard(f, r), let p = squares[index(f, r)], p.color == attacker, p.kind == .king {
                return true
            }
        }
        // Sliding pieces: bishops/queens diagonally, rooks/queens orthogonally.
        if slidingAttack(file: file, rank: rank, by: attacker,
                         dirs: GameState.bishopDirs, kinds: [.bishop, .queen]) { return true }
        if slidingAttack(file: file, rank: rank, by: attacker,
                         dirs: GameState.rookDirs, kinds: [.rook, .queen]) { return true }
        return false
    }

    private func slidingAttack(file: Int, rank: Int, by attacker: PieceColor,
                               dirs: [(Int, Int)], kinds: Set<PieceKind>) -> Bool {
        for (df, dr) in dirs {
            var f = file + df, r = rank + dr
            while onBoard(f, r) {
                if let p = squares[index(f, r)] {
                    if p.color == attacker, kinds.contains(p.kind) { return true }
                    break
                }
                f += df; r += dr
            }
        }
        return false
    }

    /// The square of `color`'s king, if present.
    public func kingSquare(of color: PieceColor) -> Square? {
        for rank in 0..<8 {
            for file in 0..<8 {
                if let p = squares[index(file, rank)], p.color == color, p.kind == .king {
                    return Square(file: file, rank: rank)
                }
            }
        }
        return nil
    }

    /// Whether `color`'s king is currently in check.
    public func isInCheck(_ color: PieceColor) -> Bool {
        guard let king = kingSquare(of: color) else { return false }
        return isAttacked(file: king.file, rank: king.rank, by: color.opposite)
    }

    // MARK: - Draw conditions

    /// The fields that define a "same position" for threefold repetition:
    /// piece placement, side to move, castling rights, and en-passant target.
    public var repetitionKey: String {
        "\(position.fenPlacement) \(sideToMove.rawValue) \(castling.fenField) \(enPassant?.algebraic ?? "-")"
    }

    /// True when neither side has enough material to deliver checkmate:
    /// K vs K, K + single minor vs K, or only bishops that all sit on the same
    /// color of square.
    public var hasInsufficientMaterial: Bool {
        var knightCount = 0
        var bishopCount = 0
        var bishopColors: Set<SquareColor> = []
        for rank in 0..<8 {
            for file in 0..<8 {
                guard let piece = squares[rank * 8 + file] else { continue }
                switch piece.kind {
                case .king:
                    continue
                case .pawn, .rook, .queen:
                    return false        // a mate is possible
                case .knight:
                    knightCount += 1
                case .bishop:
                    bishopCount += 1
                    bishopColors.insert(Square(file: file, rank: rank).color)
                }
            }
        }
        let minorCount = knightCount + bishopCount
        if minorCount <= 1 { return true }                       // K(+minor) vs K
        if knightCount == 0 && bishopColors.count == 1 { return true } // same-color bishops only
        return false
    }

    // MARK: - Move generation

    /// All fully legal moves for the side to move.
    public func legalMoves() -> [Move] {
        let mover = sideToMove
        return pseudoLegalMoves(for: mover).filter { move in
            !make(move).isInCheck(mover)
        }
    }

    /// Legal moves originating from `square`.
    public func legalMoves(from square: Square) -> [Move] {
        legalMoves().filter { $0.from == square }
    }

    /// Whether `move` is fully legal in this position.
    public func isLegal(_ move: Move) -> Bool {
        legalMoves().contains(move)
    }

    public var isCheckmate: Bool { legalMoves().isEmpty && isInCheck(sideToMove) }
    public var isStalemate: Bool { legalMoves().isEmpty && !isInCheck(sideToMove) }

    private func pseudoLegalMoves(for color: PieceColor) -> [Move] {
        var moves: [Move] = []
        for rank in 0..<8 {
            for file in 0..<8 {
                guard let piece = squares[index(file, rank)], piece.color == color else { continue }
                let from = Square(file: file, rank: rank)
                switch piece.kind {
                case .pawn:   addPawnMoves(from: from, color: color, into: &moves)
                case .knight: addStepMoves(from: from, color: color, offsets: GameState.knightOffsets, into: &moves)
                case .king:   addStepMoves(from: from, color: color, offsets: GameState.kingOffsets, into: &moves)
                              addCastlingMoves(color: color, into: &moves)
                case .bishop: addSlidingMoves(from: from, color: color, dirs: GameState.bishopDirs, into: &moves)
                case .rook:   addSlidingMoves(from: from, color: color, dirs: GameState.rookDirs, into: &moves)
                case .queen:  addSlidingMoves(from: from, color: color, dirs: GameState.bishopDirs + GameState.rookDirs, into: &moves)
                }
            }
        }
        return moves
    }

    private func addStepMoves(from: Square, color: PieceColor, offsets: [(Int, Int)], into moves: inout [Move]) {
        for (df, dr) in offsets {
            let f = from.file + df, r = from.rank + dr
            guard onBoard(f, r) else { continue }
            if let occupant = squares[index(f, r)], occupant.color == color { continue }
            moves.append(Move(from: from, to: Square(file: f, rank: r)))
        }
    }

    private func addSlidingMoves(from: Square, color: PieceColor, dirs: [(Int, Int)], into moves: inout [Move]) {
        for (df, dr) in dirs {
            var f = from.file + df, r = from.rank + dr
            while onBoard(f, r) {
                if let occupant = squares[index(f, r)] {
                    if occupant.color != color { moves.append(Move(from: from, to: Square(file: f, rank: r))) }
                    break
                }
                moves.append(Move(from: from, to: Square(file: f, rank: r)))
                f += df; r += dr
            }
        }
    }

    private func addPawnMoves(from: Square, color: PieceColor, into moves: inout [Move]) {
        let dir = color == .white ? 1 : -1
        let startRank = color == .white ? 1 : 6
        let promoRank = color == .white ? 7 : 0

        func emit(to: Square) {
            if to.rank == promoRank {
                for kind in [PieceKind.queen, .rook, .bishop, .knight] {
                    moves.append(Move(from: from, to: to, promotion: kind))
                }
            } else {
                moves.append(Move(from: from, to: to))
            }
        }

        // Single and double pushes.
        let oneRank = from.rank + dir
        if onBoard(from.file, oneRank), squares[index(from.file, oneRank)] == nil {
            emit(to: Square(file: from.file, rank: oneRank))
            let twoRank = from.rank + 2 * dir
            if from.rank == startRank, squares[index(from.file, twoRank)] == nil {
                moves.append(Move(from: from, to: Square(file: from.file, rank: twoRank)))
            }
        }

        // Captures, including en passant.
        for df in [-1, 1] {
            let f = from.file + df
            let r = from.rank + dir
            guard onBoard(f, r) else { continue }
            if let occupant = squares[index(f, r)] {
                if occupant.color != color { emit(to: Square(file: f, rank: r)) }
            } else if let ep = enPassant, ep.file == f, ep.rank == r {
                moves.append(Move(from: from, to: Square(file: f, rank: r)))
            }
        }
    }

    private func addCastlingMoves(color: PieceColor, into moves: inout [Move]) {
        let rank = color == .white ? 0 : 7
        let enemy = color.opposite
        // Can't castle out of check.
        guard !isAttacked(file: 4, rank: rank, by: enemy) else { return }

        let kingside: CastlingRights = color == .white ? .whiteKingside : .blackKingside
        let queenside: CastlingRights = color == .white ? .whiteQueenside : .blackQueenside

        if castling.contains(kingside),
           squares[index(5, rank)] == nil, squares[index(6, rank)] == nil,
           !isAttacked(file: 5, rank: rank, by: enemy),
           !isAttacked(file: 6, rank: rank, by: enemy) {
            moves.append(Move(from: Square(file: 4, rank: rank), to: Square(file: 6, rank: rank)))
        }
        if castling.contains(queenside),
           squares[index(1, rank)] == nil, squares[index(2, rank)] == nil, squares[index(3, rank)] == nil,
           !isAttacked(file: 3, rank: rank, by: enemy),
           !isAttacked(file: 2, rank: rank, by: enemy) {
            moves.append(Move(from: Square(file: 4, rank: rank), to: Square(file: 2, rank: rank)))
        }
    }

    // MARK: - Applying a move

    /// Returns the state after playing `move`. The move is assumed to be one
    /// generated for this position (pseudo-legal); legality is enforced by the
    /// callers that filter with `isInCheck`.
    public func make(_ move: Move) -> GameState {
        var next = self
        let movingIndex = index(move.from)
        guard let mover = next.squares[movingIndex] else { return next }
        let color = mover.color
        var captured = next.squares[index(move.to)] != nil

        // En passant capture: the taken pawn is beside the destination.
        if mover.kind == .pawn, let ep = enPassant, move.to == ep,
           move.from.file != move.to.file, next.squares[index(move.to)] == nil {
            next.squares[index(move.to.file, move.from.rank)] = nil
            captured = true
        }

        // Move the piece (handling promotion).
        next.squares[index(move.to)] = move.promotion.map { Piece(color: color, kind: $0) } ?? mover
        next.squares[movingIndex] = nil

        // Castling: move the rook too.
        if mover.kind == .king, abs(move.to.file - move.from.file) == 2 {
            let rank = move.from.rank
            if move.to.file == 6 {
                next.squares[index(5, rank)] = next.squares[index(7, rank)]
                next.squares[index(7, rank)] = nil
            } else if move.to.file == 2 {
                next.squares[index(3, rank)] = next.squares[index(0, rank)]
                next.squares[index(0, rank)] = nil
            }
        }

        // Update castling rights.
        if mover.kind == .king {
            next.castling.subtract(color == .white ? [.whiteKingside, .whiteQueenside]
                                                    : [.blackKingside, .blackQueenside])
        }
        for square in [move.from, move.to] {
            switch (square.file, square.rank) {
            case (0, 0): next.castling.remove(.whiteQueenside)
            case (7, 0): next.castling.remove(.whiteKingside)
            case (0, 7): next.castling.remove(.blackQueenside)
            case (7, 7): next.castling.remove(.blackKingside)
            default: break
            }
        }

        // En passant target (only after a double pawn push).
        next.enPassant = nil
        if mover.kind == .pawn, abs(move.to.rank - move.from.rank) == 2 {
            next.enPassant = Square(file: move.from.file, rank: (move.from.rank + move.to.rank) / 2)
        }

        // Clocks and side to move.
        next.halfmoveClock = (mover.kind == .pawn || captured) ? 0 : next.halfmoveClock + 1
        if color == .black { next.fullmoveNumber += 1 }
        next.sideToMove = color.opposite
        return next
    }

    /// Perft: counts leaf nodes to `depth`. Used to validate move generation.
    public func perft(_ depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = legalMoves()
        if depth == 1 { return moves.count }
        var total = 0
        for move in moves {
            total += make(move).perft(depth - 1)
        }
        return total
    }
}
