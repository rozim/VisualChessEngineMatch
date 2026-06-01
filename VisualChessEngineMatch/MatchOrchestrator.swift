import Foundation
import Combine

/// Manages a match between two engines, consisting of multiple mini-matches.
@MainActor
final class MatchOrchestrator: ObservableObject {
    enum State: Equatable {
        case idle
        case initializing
        case playing(gameNumber: Int, totalGames: Int)
        case gameOver(MatchResult, reason: String)
        case matchOver(MatchScore)
        case error(String)
    }

    enum MatchResult: Equatable {
        case whiteWin
        case blackWin
        case draw
    }

    struct MatchScore: Equatable {
        var engine1Score: Double = 0
        var engine2Score: Double = 0
        var gamesPlayed: Int = 0
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var score = MatchScore()
    
    /// The live game state.
    @Published private(set) var controller = GameController()
    /// The match clock.
    @Published private(set) var clock: MatchClock?
    
    /// Engines for the match.
    @Published private(set) var player1 = MatchPlayer()
    @Published private(set) var player2 = MatchPlayer()
    @Published private(set) var player1Info: UCIInfo?
    @Published private(set) var player2Info: UCIInfo?
    
    /// History of evaluations for graphing.
    @Published private(set) var player1EvalHistory: [Double] = []
    @Published private(set) var player2EvalHistory: [Double] = []
    
    private var config: MatchConfig?
    private var openingPositions: [String] = []
    
    /// Which player is currently White.
    private(set) var whitePlayer: MatchPlayer?
    /// Which player is currently Black.
    private(set) var blackPlayer: MatchPlayer?
    
    var whiteInfo: UCIInfo? {
        if whitePlayer === player1 { return player1Info }
        if whitePlayer === player2 { return player2Info }
        return nil
    }
    
    var blackInfo: UCIInfo? {
        if blackPlayer === player1 { return player1Info }
        if blackPlayer === player2 { return player2Info }
        return nil
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var timerCancellable: AnyCancellable?
    
    private var lastTurnTime = Date()
    private var turnStartClock: MatchClock?
    private var currentGameStartingFEN: String = GameState.standard.fen()

    init() {
        setupSubscriptions(for: player1)
        setupSubscriptions(for: player2)
    }

    func startMatch(config: MatchConfig) {
        stopMatch()
        self.config = config
        self.score = MatchScore()
        self.state = .initializing
        self.player1Info = nil
        self.player2Info = nil
        
        // Load openings.
        if let epdPath = config.epdFilePath {
            self.openingPositions = (try? EPDFile.load(path: epdPath)) ?? [GameState.standard.fen()]
        } else {
            self.openingPositions = EPDFile.loadBundled()
            if openingPositions.isEmpty {
                openingPositions = [GameState.standard.fen()]
            }
        }
        
        // Select unique positions for the match.
        self.openingPositions = EPDFile.selectUniqueRandom(from: openingPositions, count: config.miniMatchCount)
        
        player1.start(config: config.engine1)
        player2.start(config: config.engine2)
        
        // Clear existing PGN log if path is provided.
        if let pgnPath = config.pgnLogPath {
            let url: URL
            if pgnPath.hasPrefix("/") {
                url = URL(fileURLWithPath: pgnPath)
            } else {
                url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(pgnPath)
            }
            try? FileManager.default.removeItem(at: url)
            print("LOG: Initialized PGN log at \(url.path)")
        }
        
        // Handle failures.
        player1.$state.sink { [weak self] state in
            if case .failed(let msg) = state { self?.state = .error("Engine 1 failure: \(msg)") }
        }.store(in: &cancellables)
        
        player2.$state.sink { [weak self] state in
            if case .failed(let msg) = state { self?.state = .error("Engine 2 failure: \(msg)") }
        }.store(in: &cancellables)
        
        Publishers.CombineLatest(player1.$state, player2.$state)
            .filter { $0 == .ready && $1 == .ready }
            .first()
            .sink { [weak self] _ in
                self?.beginNextGame()
            }
            .store(in: &cancellables)
    }

    func stopMatch() {
        player1.stop()
        player2.stop()
        timerCancellable = nil
        cancellables.removeAll()
        state = .idle
        // Re-setup subscriptions for potential restart.
        setupSubscriptions(for: player1)
        setupSubscriptions(for: player2)
    }

    private func beginNextGame() {
        guard let config = config else { return }
        let totalGames = config.miniMatchCount * 2
        let gameNumber = score.gamesPlayed + 1
        
        guard gameNumber <= totalGames else {
            state = .matchOver(score)
            return
        }
        
        state = .playing(gameNumber: gameNumber, totalGames: totalGames)
        controller.reset()
        player1EvalHistory = []
        player2EvalHistory = []
        
        // Mini-match logic: game 1 has E1=White, game 2 has E2=White.
        let miniMatchIndex = (gameNumber - 1) / 2
        let isSecondInMini = (gameNumber - 1) % 2 == 1
        
        // Select opening for this mini-match.
        let fen = openingPositions[min(miniMatchIndex, openingPositions.count - 1)]
        currentGameStartingFEN = fen
        controller.load(fen: fen)
        
        // Swap colors every game.
        if isSecondInMini {
            // Engine 2 is White.
            whitePlayer = player2
            blackPlayer = player1
        } else {
            // Engine 1 is White.
            whitePlayer = player1
            blackPlayer = player2
        }
        
        clock = MatchClock(
            whiteTime: TimeInterval(config.engine1.timePerGame),
            blackTime: TimeInterval(config.engine2.timePerGame),
            whiteIncrement: config.engine1.incrementPerMove,
            blackIncrement: config.engine2.incrementPerMove
        )
        turnStartClock = clock
        
        lastTurnTime = Date()
        player1Info = nil
        player2Info = nil
        startTimer()
        nextTurn()
    }

    private func nextTurn() {
        guard case .playing = state, let clock = clock, let config = config else { return }
        let activePlayer = controller.sideToMove == .white ? whitePlayer : blackPlayer
        let nodeLimit = activePlayer === player1 ? config.engine1.nodeLimit : config.engine2.nodeLimit
        activePlayer?.search(state: controller.game, clock: clock, mode: config.mode, nodeLimit: nodeLimit)
    }

    private func setupSubscriptions(for player: MatchPlayer) {
        player.bestMovePublisher
            .sink { [weak self] uci in
                guard let self = self else { return }
                self.handleEngineMove(uci, from: player)
            }
            .store(in: &cancellables)
            
        player.infoPublisher
            .sink { [weak self] info in
                guard let self = self else { return }
                if player === self.player1 { self.player1Info = info }
                else if player === self.player2 { self.player2Info = info }
            }
            .store(in: &cancellables)
    }

    private func handleEngineMove(_ uci: String, from player: MatchPlayer) {
        guard case .playing = state else { return }
        
        let side = controller.sideToMove
        let activePlayer = side == .white ? whitePlayer : blackPlayer
        guard player === activePlayer else { return }
        
        let elapsed = Date().timeIntervalSince(lastTurnTime)
        if var finalClock = turnStartClock {
            finalClock.consume(elapsed: elapsed, for: side)
            finalClock.addIncrement(for: side)
            self.clock = finalClock
            self.turnStartClock = finalClock
            self.lastTurnTime = Date()
        }
        
        if config?.mode == .time && clock?.hasFlagFallen(for: side) == true {
            recordGameResult(side == .white ? .blackWin : .whiteWin, reason: "Time forfeit")
            return
        }
        
        guard let move = Move(uci: uci) else {
            recordGameResult(side == .white ? .blackWin : .whiteWin, reason: "Illegal move UCI: \(uci)")
            return
        }
        
        if controller.attemptMove(from: move.from, to: move.to, promotion: move.promotion) == .illegal {
            recordGameResult(side == .white ? .blackWin : .whiteWin, reason: "Illegal move: \(uci)")
            return
        }
        
        if controller.result != .ongoing {
            recordGameResult(matchResult(for: controller.result), reason: controller.statusText)
            return
        }
        
        // Record evaluations to history for graphing.
        // We use win probability (0...1) normalized to White.
        recordEvalToHistory()
        
        lastTurnTime = Date()
        nextTurn()
    }

    private func recordEvalToHistory() {
        if let info1 = player1Info {
            let cp = info1.scoreCentipawns ?? 0
            let winProb = 1.0 / (1.0 + pow(10.0, -Double(cp) / 400.0))
            let whiteWinProb = (player1 === whitePlayer) ? winProb : (1.0 - winProb)
            player1EvalHistory.append(whiteWinProb)
        }
        if let info2 = player2Info {
            let cp = info2.scoreCentipawns ?? 0
            let winProb = 1.0 / (1.0 + pow(10.0, -Double(cp) / 400.0))
            let whiteWinProb = (player2 === whitePlayer) ? winProb : (1.0 - winProb)
            player2EvalHistory.append(whiteWinProb)
        }
    }

    private func pgnResult(for result: MatchResult) -> String {
        switch result {
        case .whiteWin: return "1-0"
        case .blackWin: return "0-1"
        case .draw: return "1/2-1/2"
        }
    }

    private func matchResult(for result: GameController.GameResult) -> MatchResult {
        switch result {
        case .checkmate(let winner): return winner == .white ? .whiteWin : .blackWin
        default: return .draw
        }
    }

    private func recordGameResult(_ result: MatchResult, reason: String) {
        timerCancellable = nil
        
        // Add to match score.
        // Identify which engine was which.
        let winnerIsE1: Double
        let winnerIsE2: Double
        
        switch result {
        case .whiteWin:
            if whitePlayer === player1 { winnerIsE1 = 1; winnerIsE2 = 0 }
            else { winnerIsE1 = 0; winnerIsE2 = 1 }
        case .blackWin:
            if blackPlayer === player1 { winnerIsE1 = 1; winnerIsE2 = 0 }
            else { winnerIsE1 = 0; winnerIsE2 = 1 }
        case .draw:
            winnerIsE1 = 0.5; winnerIsE2 = 0.5
        }
        
        score.engine1Score += winnerIsE1
        score.engine2Score += winnerIsE2
        score.gamesPlayed += 1
        
        // Log to PGN if path is provided.
        if let pgnPath = config?.pgnLogPath {
            let info = PGNLogger.GameInfo(
                event: "VisualChessEngineMatch",
                round: "\(score.gamesPlayed)",
                white: whitePlayer?.name ?? "White",
                black: blackPlayer?.name ?? "Black",
                result: pgnResult(for: result),
                fen: currentGameStartingFEN,
                moves: controller.sanHistory
            )
            let pgn = PGNLogger.generatePGN(info: info)
            try? PGNLogger.appendToLog(pgn: pgn, filePath: pgnPath)
        }
        
        state = .gameOver(result, reason: reason)
        
        // Automatic transition to next game after a brief delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if case .gameOver = self.state {
                self.beginNextGame()
            }
        }
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateClock() }
    }

    private func updateClock() {
        guard case .playing = state, let side = Optional(controller.sideToMove) else { return }
        let elapsed = Date().timeIntervalSince(lastTurnTime)
        
        if var currentClock = turnStartClock {
            currentClock.consume(elapsed: elapsed, for: side)
            self.clock = currentClock // Published property update
            if config?.mode == .time && currentClock.hasFlagFallen(for: side) {
                recordGameResult(side == .white ? .blackWin : .whiteWin, reason: "Time forfeit")
            }
        }
    }
}
