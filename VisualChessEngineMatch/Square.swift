import Foundation

/// The two colors a board square can be painted.
public enum SquareColor: Equatable {
    case light
    case dark
}

/// A single square on the chess board, addressed by `file` (column) and
/// `rank` (row), both zero-based.
///
/// - `file` 0...7 maps to columns a...h
/// - `rank` 0...7 maps to rows 1...8
///
/// The bottom-left square from White's point of view is a1 = (file: 0, rank: 0),
/// which is a dark square by the rules of chess.
public struct Square: Equatable, Hashable {
    public let file: Int
    public let rank: Int

    public init(file: Int, rank: Int) {
        precondition((0..<8).contains(file), "file out of range: \(file)")
        precondition((0..<8).contains(rank), "rank out of range: \(rank)")
        self.file = file
        self.rank = rank
    }

    /// The painted color of this square. a1 is dark, so a square is light when
    /// the sum of its file and rank is odd.
    public var color: SquareColor {
        (file + rank).isMultiple(of: 2) ? .dark : .light
    }

    /// The file as its algebraic letter, e.g. 'a' for file 0.
    public var fileLetter: Character {
        Character(UnicodeScalar(UInt8(UInt8(ascii: "a") + UInt8(file))))
    }

    /// The rank as its algebraic number, e.g. 1 for rank 0.
    public var rankNumber: Int {
        rank + 1
    }

    /// Algebraic coordinate, e.g. "e4".
    public var algebraic: String {
        "\(fileLetter)\(rankNumber)"
    }
}
