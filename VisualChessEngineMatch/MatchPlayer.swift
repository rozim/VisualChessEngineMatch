import Foundation
import Combine

/// Drives a single UCI engine for a match: handles timed move generation.
final class MatchPlayer: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case ready
        case thinking
        case failed(String)
        case stopped
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var name: String = ""
    
    let infoPublisher = PassthroughSubject<UCIInfo, Never>()
    let bestMovePublisher = PassthroughSubject<String, Never>()

    private var engine: UCIEngine?
    private var uciOptions: [String: String] = [:]

    init() {}

    func start(config: EngineConfig) {
        self.uciOptions = config.uciOptions
        self.name = config.name
        self.state = .starting

        let engine = UCIEngine(
            onLine: { [weak self] line in
                DispatchQueue.main.async {
                    self?.handle(line)
                }
            },
            onTerminate: { [weak self] in
                DispatchQueue.main.async {
                    self?.handleTermination()
                }
            }
        )
        self.engine = engine

        switch engine.start(path: config.binaryPath) {
        case .failure(let error):
            self.engine = nil
            self.state = .failed(error.message)
        case .success:
            engine.send("uci")
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        if case .failed = state {} else { state = .stopped }
    }

    func search(state: GameState, clock: MatchClock) {
        guard let engine = engine else { return }
        self.state = .thinking
        engine.send("position fen \(state.fen())")
        let wtime = clock.timeMs(for: .white)
        let btime = clock.timeMs(for: .black)
        engine.send("go wtime \(wtime) btime \(btime)")
    }

    private func handle(_ line: String) {
        if let id = UCIProtocol.parseID(line) {
            if id.0 == .name {
                let reportedName = id.1
                if !name.contains(reportedName) {
                    name += " (\(reportedName))"
                }
            }
        } else if line == "uciok" {
            for (name, value) in uciOptions {
                engine?.send("setoption name \(name) value \(value)")
            }
            engine?.send("isready")
        } else if line == "readyok" {
            if state == .starting {
                state = .ready
            }
        } else if let info = UCIProtocol.parseInfo(line) {
            infoPublisher.send(info)
        } else if let move = UCIProtocol.parseBestMove(line) {
            state = .ready
            bestMovePublisher.send(move)
        }
    }

    private func handleTermination() {
        engine = nil
        if case .failed = state { return }
        state = .stopped
    }
}
