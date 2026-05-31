# VisualEngineBattle

Conventions:
- Write code in Swift.
- Build/test with `xcodebuild` only (per `CLAUDE.md`); never `swift build`/`swiftc`.
- Every new source/test file must be wired into BOTH the app and (if it holds
  testable logic) the test target in `VisualChessEngineMatch.xcodeproj/project.pbxproj`.
- Keep each item to its own commit; run the full suite before committing.
- American spelling ("analyze").
- Reuse code by copying from ../ClaudeSwiftChessUI/ if possible.
- Do not install 3rd party libraries
- In input dialogs trim leading/trailing whitespace from text fields

Goal:
- Create an OSX application that displays a chess board
- The chess board will show the current game in a match between two chess engines
- Each engine can be configured separately
- Find an EPD file of unbalanced chess engine match starting positions

- Engine configuration -- this applies to each of the 2 engines
-- Binary path - default to /usr/local/bin/stockfish
-- Once the engine starts up, query it for UCI options
-- Time per game
-- Increment per move

- Match configuration
-- Number of mini matches to play - default to 10
-- Time per game, defaults to 10 seconds
-- Increment per move, defaults to 0.1 seconds
-- EPD file of openings - default to the file in this repository

- Logic
-- For each mini match, choose a unique starting position at random from the EPD file
-- The engines will play from this starting position twice, once as white and once as black
-- Use the UCI seach command that tells the engine how much time is available
-- Terminate games on insufficient material, lack of progresss, etc

- Display
-- Current chess board
-- Engine names
-- Time remaining for each engine
-- Mini match number
-- Each engine cumulative score (win=1, draw=0.5, loss=0)
-- Current moves in PGN of current game. PGN SAN moves on screen will use unicode pieces, so for queen moves, do not use the letter Q, instead use the unicocde chess queen
-- Current prediction/PV from each engine -- this is 1 line per engine
-- Bar graph over time of the engines evaluation prediction

- Write a PGN log file of the current match
-- Overwrite the file when starting
-- Append each game to file
