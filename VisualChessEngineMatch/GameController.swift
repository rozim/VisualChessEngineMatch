import Foundation
import Combine

/// Observable owner of the live game: holds the current `GameState`, applies
/// user moves (validating legality), tracks history for undo, and detects the
/// game result (mate, stalemate, and the three draw rules).
///
/// Derived state (legal moves, result, status text, checked-king square) is
/// cached and recomputed only when the game changes, so views that redraw for
/// unrelated reasons — such as frequent engine-analysis updates — stay cheap.
@MainActor
final class GameController: ObservableObject {

    /// Outcome of attempting a user move.
    enum MoveResult: Equatable {
        case made
        case illegal
        case needsPromotion
    }

    /// How (or whether) the game has ended.
    enum GameResult: Equatable {
        case ongoing
        case checkmate(winner: PieceColor)
        case stalemate
        case fiftyMove
        case threefold
        case insufficientMaterial

        var isOver: Bool { self != .ongoing }
    }

    @Published private(set) var game: GameState = .standard
    @Published private(set) var moveHistory: [Move] = []
    /// SAN for each played move, recorded as the move is made.
    @Published private(set) var sanHistory: [String] = []
    /// Figurine SAN for each played move, for display on screen.
    @Published private(set) var figurineHistory: [String] = []

    // Cached derived state (recomputed in `recomputeDerived`).
    @Published private(set) var result: GameResult = .ongoing
    @Published private(set) var statusText: String = ""
    private(set) var legalMovesCache: [Move] = []
    private(set) var checkedKingSquare: Square?

    private var stateHistory: [GameState] = []
    /// Count of each position (by repetition key) seen in the game so far.
    private var positionCounts: [String: Int] = [:]

    init() {
        positionCounts[game.repetitionKey] = 1
        recomputeDerived()
    }

    // MARK: - Read-only accessors

    var position: Position { game.position }
    var fen: String { game.fen() }
    var sideToMove: PieceColor { game.sideToMove }
    var lastMove: Move? { moveHistory.last }
    var isGameOver: Bool { result.isOver }

    func piece(at square: Square) -> Piece? { game.piece(at: square) }
    func legalMoves(from square: Square) -> [Move] { legalMovesCache.filter { $0.from == square } }

    // MARK: - Making moves

    /// Attempts to move from one square to another. If the move is a pawn
    /// promotion and no `promotion` piece is given, returns `.needsPromotion`
    /// without changing the game so the UI can ask which piece.
    @discardableResult
    func attemptMove(from: Square, to: Square, promotion: PieceKind? = nil) -> MoveResult {
        let candidates = legalMovesCache.filter { $0.from == from && $0.to == to }
        guard !candidates.isEmpty else { return .illegal }

        if candidates.contains(where: { $0.promotion != nil }) {
            guard let promotion,
                  let move = candidates.first(where: { $0.promotion == promotion }) else {
                return .needsPromotion
            }
            apply(move)
            return .made
        }

        apply(candidates[0])
        return .made
    }

    func apply(_ move: Move) {
        // SAN is computed against the position *before* the move.
        let san = game.san(for: move) ?? move.uci
        let figurine = game.san(for: move, figurine: true) ?? move.uci
        stateHistory.append(game)
        game = game.make(move)
        moveHistory.append(move)
        sanHistory.append(san)
        figurineHistory.append(figurine)
        positionCounts[game.repetitionKey, default: 0] += 1
        recomputeDerived()
    }

    func undo() {
        guard let previous = stateHistory.popLast() else { return }
        decrementCount(for: game.repetitionKey)
        game = previous
        if !moveHistory.isEmpty { moveHistory.removeLast() }
        if !sanHistory.isEmpty { sanHistory.removeLast() }
        if !figurineHistory.isEmpty { figurineHistory.removeLast() }
        recomputeDerived()
    }

    func reset() {
        game = .standard
        moveHistory = []
        sanHistory = []
        figurineHistory = []
        stateHistory = []
        positionCounts = [game.repetitionKey: 1]
        recomputeDerived()
    }

    /// Replaces the game with the position described by `fen`. Returns false
    /// (leaving the game unchanged) if the FEN is invalid.
    @discardableResult
    func load(fen: String) -> Bool {
        guard let state = GameState(fen: fen) else { return false }
        game = state
        moveHistory = []
        sanHistory = []
        figurineHistory = []
        stateHistory = []
        positionCounts = [game.repetitionKey: 1]
        recomputeDerived()
        return true
    }

    // MARK: - Derived state

    private func decrementCount(for key: String) {
        guard let count = positionCounts[key] else { return }
        if count <= 1 { positionCounts[key] = nil } else { positionCounts[key] = count - 1 }
    }

    private func recomputeDerived() {
        legalMovesCache = game.legalMoves()
        let inCheck = game.isInCheck(game.sideToMove)
        checkedKingSquare = inCheck ? game.kingSquare(of: game.sideToMove) : nil
        result = computeResult(inCheck: inCheck)
        statusText = Self.describe(result, sideToMove: game.sideToMove, inCheck: inCheck)
    }

    private func computeResult(inCheck: Bool) -> GameResult {
        if legalMovesCache.isEmpty {
            return inCheck ? .checkmate(winner: game.sideToMove.opposite) : .stalemate
        }
        if game.hasInsufficientMaterial { return .insufficientMaterial }
        if (positionCounts[game.repetitionKey] ?? 0) >= 3 { return .threefold }
        if game.halfmoveClock >= 100 { return .fiftyMove }
        return .ongoing
    }

    private static func describe(_ result: GameResult,
                                 sideToMove: PieceColor, inCheck: Bool) -> String {
        switch result {
        case .checkmate(let winner):
            return "Checkmate — \(winner == .white ? "White" : "Black") wins"
        case .stalemate:
            return "Stalemate — draw"
        case .fiftyMove:
            return "Draw — fifty-move rule"
        case .threefold:
            return "Draw — threefold repetition"
        case .insufficientMaterial:
            return "Draw — insufficient material"
        case .ongoing:
            let side = sideToMove == .white ? "White" : "Black"
            return inCheck ? "\(side) to move — check" : "\(side) to move"
        }
    }
}
