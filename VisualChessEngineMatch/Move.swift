import Foundation

/// A chess move: the square moved from, the square moved to, and—for a pawn
/// reaching the back rank—the piece it promotes to.
public struct Move: Equatable, Hashable {
    public let from: Square
    public let to: Square
    public let promotion: PieceKind?

    public init(from: Square, to: Square, promotion: PieceKind? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    /// The move in UCI long-algebraic notation, e.g. "e2e4" or "e7e8q".
    public var uci: String {
        var s = from.algebraic + to.algebraic
        if let promotion {
            s += promotion.rawValue.lowercased()
        }
        return s
    }
}
