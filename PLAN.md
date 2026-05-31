# VisualEngineBattle — Implementation Plan

A macOS SwiftUI app that runs a match between two configurable UCI chess engines
and visualizes the games live. Swift only; built/tested with `xcodebuild`.

---

## 0. Environment study (confirmed by reading the code)

- **This repo has no `.xcodeproj` yet** — only `CLAUDE.md`, `LICENSE`,
  `.gitignore`. We create the project (app + test targets) from scratch.
- **`/usr/local/bin/stockfish` exists** (Stockfish, owned by root, executable) —
  it matches the CLAUDE.md default exactly. Keep it as the prefilled, editable
  default. (`/opt/homebrew/bin/stockfish` does not exist.)
- Toolchain: **Xcode 26.5, Swift 6.3.2**. `xcodebuild` only.
- **The reference repo `../ClaudeSwiftChessUI/` is fully implemented and an
  excellent fit to copy from** (CLAUDE.md tells us to). It's a single-game
  engine *analysis* GUI: 16 source files (~2,300 LOC) + 10 test files (~1,000
  LOC). I read every source file. Accurate inventory and reuse notes below.
- **No EPD/PGN/openings file exists** in either repo — we must source one.

### Reference repo file inventory (real APIs, verified)

Pure model (no UI — copy as-is into app **and** test target):
- `Square.swift` — `Square(file,rank)`, `SquareColor`, `algebraic`, file/rank helpers.
- `Piece.swift` — `PieceColor{.white,.black}`, `PieceKind{K,Q,R,B,N,P}` (rawValue =
  SAN letters), `Piece`, FEN char in/out, `assetName` ("wK","bP").
- `Move.swift` — `Move(from,to,promotion)`, `uci`, and `Move(uci:)` parser.
- `GameState.swift` (463 LOC) — **the real engine**: FEN parse/emit, full legal
  move generation (castling, en passant, promotion), `make`, `isInCheck`,
  `isCheckmate`/`isStalemate`, `hasInsufficientMaterial`, `repetitionKey`,
  `halfmoveClock`/`fullmoveNumber`, `perft`. `CastlingRights`.
- `Position.swift` — placement-only grid + FEN placement (used by board/FEN).
- `SAN.swift` — `GameState.san(for:)` and `sanLine(forUCIMoves:)`.
  ⚠️ Currently emits the **letter** for pieces (`mover.kind.rawValue`). CLAUDE.md
  requires **unicode glyphs on screen** (e.g. ♛ for queen, no letter for pawns).
  See §3.

Engine integration (copy, then extend for match play):
- `UCIProtocol.swift` — stateless parsers: `parseID`, `parseOption` →
  `UCIOption`/`UCIOptionType`, `parseInfo` → `UCIInfo` (depth, score cp/mate
  side-to-move-relative, pv, `scoreText(sideToMove:)`), `parseBestMove`.
- `UCIEngine.swift` — `Process` wrapper: validate path, launch, line-buffered
  stdout callback, `send`, `stop`. Reusable as-is for both engines.
- `EngineSession.swift` — `@MainActor ObservableObject`: handshake, options,
  analysis. ⚠️ It is built for **continuous analysis** (`go infinite`, MultiPV),
  *not* timed move generation. For engine-vs-engine play we need a different
  driver (see §2) — reuse the handshake/parsing patterns, not this class verbatim.
- `EngineOptionStore.swift` — per-path option persistence in UserDefaults. Reuse.

UI:
- `BoardView.swift` — ⚠️ **interactive** (drag/click to move via `GameController`).
  For a match we want a **read-only** board. Either add a read-only mode or make
  a slimmer display board. Reuses `Image(piece.assetName)` from `Assets.xcassets`.
- `EvalBarView.swift` — vertical white-relative eval bar. Reuse + extend to the
  eval-over-time bar graph the spec asks for.
- `EngineConfigView.swift` — path picker + typed UCI option editor (already trims
  whitespace, already shows `/usr/local/bin/stockfish` as placeholder). Reuse ×2.
- `GameController.swift` — `@MainActor` owner of one game: applies moves, caches
  legal moves, and computes `GameResult` (checkmate/stalemate/fiftyMove/threefold/
  insufficientMaterial) with repetition counting. **Reuse its result logic** for
  game-end detection in the match.
- `ContentView.swift` — layout incl. a private `MovesView` (numbered SAN pairs)
  and analysis pane. Cannibalize `MovesView`.
- `ChessApp.swift` — `@main` App. Trivial.

Also copy: **`Assets.xcassets`** (piece imagesets wK…bP) and credit
`PIECES_CREDITS.md`. Tests: adapt the 10 reference test files as our baseline.

---

## 1. What to REUSE vs BUILD

**Reuse essentially unchanged:** `Square`, `Piece`, `Move`, `GameState`,
`Position`, `UCIProtocol`, `UCIEngine`, `EngineOptionStore`, `EvalBarView`,
`EngineConfigView`, `Assets.xcassets`, and the model/protocol test files.

**Reuse with adaptation:** `SAN` (add unicode rendering), `BoardView` (read-only
mode), `GameController` (use its result-detection for match games), `MovesView`
(extract from ContentView, switch to unicode SAN).

**Build new (the actual point of this project):**
- `EngineConfig` — per engine: binary path (default `/usr/local/bin/stockfish`),
  time per game, increment per move, chosen UCI option overrides.
- `MatchConfig` — # mini-matches (default 10), time per game (default 10s),
  increment (default 0.1s), EPD path (default the bundled file).
- `EPDFile` — parse EPD; pick **N unique** random start positions.
- `MatchClock` — per-side remaining time; decrement by think time, add increment;
  flag-fall ⇒ loss.
- `MatchPlayer` — drives ONE engine for **timed move generation**: handshake,
  then per move `position fen … [moves …]` + `go wtime btime winc binc`, capture
  latest `UCIInfo` (eval + PV for display) and the final `bestmove`. (New, because
  `EngineSession` only does `go infinite`. Built on `UCIEngine`+`UCIProtocol`.)
- `MatchEngine` — `@MainActor` orchestrator: for each mini-match pick a unique
  random EPD position; play it **twice** swapping White/Black; feed moves to a
  `GameState`; detect end via `GameController`'s result rules + flag-fall; keep
  cumulative scores (win 1 / draw 0.5 / loss 0); collect per-move eval samples.
- `PGNLogger` — overwrite file at match start; append each finished game (with
  tags: Event, Site, Round, White, Black, Result, FEN/SetUp, TimeControl).
- New views: `MatchView`/`ContentView` (board + scoreboard + moves + per-engine
  PV + eval graph), `ScoreboardView` (names, live clocks, mini-match #, scores),
  `MatchConfigView` (Start/Stop + settings), per-engine `EngineConfigView` ×2.

---

## 2. Engine-vs-engine move loop (key new design)

For each move of a game:
1. `position fen <startFEN> moves <uci…>` to the side-to-move's engine.
2. `go wtime <wms> btime <bms> winc <winc> binc <binc>`.
3. Stream `info` lines → update that engine's live PV + eval (white-relative).
4. On `bestmove`, stop the clock, apply the move to `GameState`, add increment,
   check termination (mate/stalemate/insufficient/fifty/threefold, flag-fall,
   or an illegal/`(none)` move ⇒ that engine loses), then hand off to the other
   engine. Both engine processes stay alive across the whole match.

Time accounting: measure wall-clock around think; the engine self-manages via the
UCI time fields. Flag-fall is adjudicated by us (engines don't forfeit on time).

---

## 3. SAN unicode requirement

CLAUDE.md: on-screen PGN SAN uses unicode pieces (queen = unicode glyph, pawns
get no letter). The **PGN log file** should stay standard ASCII SAN (real PGN is
ASCII). Plan: parameterize SAN piece rendering — `san(for:, figurine: Bool)` (or a
small post-map from `PieceKind` → unicode) — display uses figurine, file uses
letters. Add tests for both.

---

## 4. EPD openings file (decision needed — Q2)

CLAUDE.md: "Find an EPD file of unbalanced chess engine match starting positions"
and default to "the file in this repository." Plan: commit a public
unbalanced-openings set (UHO / "Unbalanced Human Openings" style) as
`Resources/openings.epd`, added to the app bundle. If you have a specific file,
point me to it.

---

## 5. CLAUDE.md discipline

- Swift only; `xcodebuild` only (never `swift build`/`swiftc`).
- Every new source file wired into the app target; every file with testable logic
  also into the test target — via edits to
  `VisualChessEngineMatch.xcodeproj/project.pbxproj`.
- American spelling. No third-party libraries. Trim whitespace on dialog fields.
- **One item per commit; run the full suite before each commit.**

### Proposed commit sequence (each builds + passes tests)
1. Create Xcode project (app + test targets); empty window builds via xcodebuild.
2. Copy `Square`/`Piece`/`Move`/`Position`/`GameState` + their tests; wire both
   targets; suite green.
3. Copy `SAN` + tests; add unicode (figurine) rendering + tests.
4. Copy `UCIProtocol`/`UCIEngine`/`EngineOptionStore` + tests.
5. Copy `Assets.xcassets` + `BoardView` (read-only mode); basic display.
6. `EngineConfig`/`MatchConfig` models + tests.
7. `EPDFile` parse + unique-random selection + tests; add `Resources/openings.epd`.
8. `MatchClock` + tests.
9. `MatchPlayer` (timed move generation) + tests.
10. `MatchEngine` orchestration (dual engines, color swap, scoring, termination)
    + tests.
11. `PGNLogger` (overwrite/append, tags) + tests.
12. `ScoreboardView` + `MovesView` (unicode) + per-engine PV view.
13. Eval-over-time bar graph (extend `EvalBarView`).
14. `EngineConfigView` ×2 + `MatchConfigView` (Start/Stop).
15. Wire `ContentView`; end-to-end manual run with real Stockfish vs Stockfish.

---

## Questions before I start

1. **Reuse scope** — I plan to copy the reference modules heavily (per CLAUDE.md)
   and rename the module from `ChessUI`. Good?
2. **EPD source** — OK to bundle a public UHO-style set as
   `Resources/openings.epd`, or do you have a specific file to commit?
3. **PGN SAN** — confirm: **figurine/unicode on screen**, **plain ASCII in the
   `.pgn` file**. (Or do you want unicode in the file too?)
4. **Eval graph** — a per-move bar graph of the white-relative eval over the
   current game (matches "bar graph over time of the engines evaluation"),
   agreed? Whose eval — the side-to-move's reported score, normalized to White?
