import Foundation

/// The kind of a UCI engine option, as advertised in an `option ... type ...`
/// line of the UCI handshake.
public enum UCIOptionType: String, Equatable {
    case check
    case spin
    case combo
    case button
    case string
    case unknown
}

/// A configurable engine option advertised during the UCI handshake.
public struct UCIOption: Equatable {
    public let name: String
    public let type: UCIOptionType
    public let defaultValue: String?
    public let min: Int?
    public let max: Int?
    /// Allowed values for a `combo` option.
    public let vars: [String]

    public init(name: String, type: UCIOptionType, defaultValue: String? = nil,
                min: Int? = nil, max: Int? = nil, vars: [String] = []) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
        self.vars = vars
    }
}

/// A parsed `info` line emitted by the engine while searching.
public struct UCIInfo: Equatable {
    public var depth: Int?
    public var selDepth: Int?
    public var multipv: Int?
    /// Score in centipawns from the side-to-move's point of view (nil if mate).
    public var scoreCentipawns: Int?
    /// Moves to mate (positive = side to move mates), if this is a mate score.
    public var scoreMate: Int?
    public var nodes: Int?
    public var nps: Int?
    public var timeMillis: Int?
    /// Principal variation as a list of moves in UCI long-algebraic form.
    public var pv: [String] = []

    public init() {}

    /// True when the line carried no analysis we care to display (e.g.
    /// `info string ...` or a currmove-only update).
    public var isEmpty: Bool {
        depth == nil && scoreCentipawns == nil && scoreMate == nil && pv.isEmpty
    }

    /// A short human-readable score, e.g. "+0.34" or "#-3", from White's point
    /// of view given whose turn it is.
    public func scoreText(sideToMove: PieceColor) -> String? {
        let sign = sideToMove == .white ? 1 : -1
        if let mate = scoreMate {
            let m = mate * sign
            return "#\(m)"
        }
        if let cp = scoreCentipawns {
            let pawns = Double(cp * sign) / 100.0
            return String(format: "%+.2f", pawns)
        }
        return nil
    }
}

/// Stateless parsers for the lines a UCI engine sends to the GUI.
public enum UCIProtocol {

    /// Parses an `id name <...>` / `id author <...>` line.
    /// Returns the kind (`.name` or `.author`) and the trailing value.
    public enum IDKind { case name, author }
    public static func parseID(_ line: String) -> (IDKind, String)? {
        let tokens = tokenize(line)
        guard tokens.count >= 3, tokens[0] == "id" else { return nil }
        let value = tokens[2...].joined(separator: " ")
        switch tokens[1] {
        case "name": return (.name, value)
        case "author": return (.author, value)
        default: return nil
        }
    }

    /// Parses an `option name <...> type <...> [default ...] [min ...] [max ...]
    /// [var ...]...` line. The option name and values may contain spaces, so the
    /// parse is keyword-driven.
    public static func parseOption(_ line: String) -> UCIOption? {
        let tokens = tokenize(line)
        guard tokens.first == "option" else { return nil }

        let keywords: Set<String> = ["name", "type", "default", "min", "max", "var"]
        var name = ""
        var typeRaw = ""
        var defaultValue: String?
        var minValue: Int?
        var maxValue: Int?
        var vars: [String] = []

        var currentKey = ""
        var buffer: [String] = []

        func flush() {
            let value = buffer.joined(separator: " ")
            switch currentKey {
            case "name": name = value
            case "type": typeRaw = value
            case "default": defaultValue = value
            case "min": minValue = Int(value)
            case "max": maxValue = Int(value)
            case "var": vars.append(value)
            default: break
            }
            buffer.removeAll(keepingCapacity: true)
        }

        for token in tokens.dropFirst() {
            if keywords.contains(token) {
                if !currentKey.isEmpty { flush() }
                currentKey = token
            } else {
                buffer.append(token)
            }
        }
        if !currentKey.isEmpty { flush() }

        guard !name.isEmpty else { return nil }
        let type = UCIOptionType(rawValue: typeRaw) ?? .unknown
        return UCIOption(name: name, type: type, defaultValue: defaultValue,
                         min: minValue, max: maxValue, vars: vars)
    }

    /// Parses an `info ...` line into the fields we display.
    public static func parseInfo(_ line: String) -> UCIInfo? {
        let tokens = tokenize(line)
        guard tokens.first == "info" else { return nil }
        // We don't surface "info string ..." messages as analysis.
        if tokens.count >= 2, tokens[1] == "string" { return nil }

        var info = UCIInfo()
        var i = 1
        func nextInt() -> Int? {
            guard i + 1 < tokens.count, let v = Int(tokens[i + 1]) else { return nil }
            i += 1
            return v
        }
        while i < tokens.count {
            switch tokens[i] {
            case "depth": info.depth = nextInt()
            case "seldepth": info.selDepth = nextInt()
            case "multipv": info.multipv = nextInt()
            case "nodes": info.nodes = nextInt()
            case "nps": info.nps = nextInt()
            case "time": info.timeMillis = nextInt()
            case "score":
                if i + 2 < tokens.count {
                    let kind = tokens[i + 1]
                    let value = Int(tokens[i + 2])
                    if kind == "cp" { info.scoreCentipawns = value; i += 2 }
                    else if kind == "mate" { info.scoreMate = value; i += 2 }
                }
            case "pv":
                info.pv = Array(tokens[(i + 1)...])
                i = tokens.count
            default:
                break
            }
            i += 1
        }
        return info.isEmpty ? nil : info
    }

    /// Parses a `bestmove <move> [ponder <move>]` line, returning the best move
    /// in UCI long-algebraic form (e.g. "e2e4", or "(none)").
    public static func parseBestMove(_ line: String) -> String? {
        let tokens = tokenize(line)
        guard tokens.count >= 2, tokens[0] == "bestmove" else { return nil }
        return tokens[1]
    }

    /// Splits a line on runs of whitespace, dropping empty fields.
    static func tokenize(_ line: String) -> [String] {
        line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }
}
