import Foundation

/// The color of a chess piece / the side to move.
public enum PieceColor: String, Equatable, CaseIterable {
    case white = "w"
    case black = "b"

    /// The other color.
    public var opposite: PieceColor { self == .white ? .black : .white }
}

/// The six kinds of chess piece. Raw values are the standard one-letter
/// abbreviations used in algebraic notation (N for knight).
public enum PieceKind: String, Equatable, CaseIterable {
    case king = "K"
    case queen = "Q"
    case rook = "R"
    case bishop = "B"
    case knight = "N"
    case pawn = "P"

    /// The unicode figurine for this piece kind.
    /// Note: Figurine SAN usually uses the solid symbols (black set) for better visibility
    /// on screen regardless of the piece color.
    public var figurine: String {
        switch self {
        case .king: return "♚"
        case .queen: return "♛"
        case .rook: return "♜"
        case .bishop: return "♝"
        case .knight: return "♞"
        case .pawn: return "♟"
        }
    }
}

/// A chess piece: a color and a kind.
public struct Piece: Equatable, Hashable {
    public let color: PieceColor
    public let kind: PieceKind

    public init(color: PieceColor, kind: PieceKind) {
        self.color = color
        self.kind = kind
    }

    /// The name of the image asset for this piece, e.g. "wK" (white king) or
    /// "bP" (black pawn). Matches the imageset names in Assets.xcassets.
    public var assetName: String {
        "\(color.rawValue)\(kind.rawValue)"
    }

    /// The FEN letter for this piece: uppercase for White, lowercase for Black
    /// (e.g. "N" for a white knight, "p" for a black pawn).
    public var fenCharacter: Character {
        let letter = kind.rawValue
        return color == .white ? Character(letter) : Character(letter.lowercased())
    }

    /// Builds a piece from a FEN letter (uppercase = White, lowercase = Black),
    /// or returns nil if the character is not a valid piece letter.
    public init?(fenCharacter c: Character) {
        let isWhite = c.isUppercase
        guard let kind = PieceKind(rawValue: String(c).uppercased()) else { return nil }
        self.init(color: isWhite ? .white : .black, kind: kind)
    }
}
