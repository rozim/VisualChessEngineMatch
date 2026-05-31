import Foundation

/// Drives an external UCI chess-engine process: validates the binary path,
/// launches it, streams its stdout line-by-line to a callback, and writes
/// commands to its stdin.
///
/// All output lines are delivered on a private serial queue, so callers that
/// touch UI state must hop to the main thread themselves.
public final class UCIEngine {

    /// Why a path could not be launched. `validate(path:)` returns these without
    /// starting anything.
    public enum LaunchError: Error, Equatable {
        case emptyPath
        case notFound(String)
        case isDirectory(String)
        case notExecutable(String)
        case launchFailed(String)

        public var message: String {
            switch self {
            case .emptyPath: return "Enter a path to the engine binary."
            case .notFound(let p): return "No file exists at “\(p)”."
            case .isDirectory(let p): return "“\(p)” is a folder, not a file."
            case .notExecutable(let p): return "“\(p)” is not executable."
            case .launchFailed(let m): return "Could not launch the engine: \(m)"
            }
        }
    }

    private var process: Process?
    private var stdinPipe: Pipe?
    private let queue = DispatchQueue(label: "com.example.ChessUI.uci")
    private var lineBuffer = Data()
    private let onLine: (String) -> Void
    private let onTerminate: () -> Void

    public init(onLine: @escaping (String) -> Void,
                onTerminate: @escaping () -> Void = {}) {
        self.onLine = onLine
        self.onTerminate = onTerminate
        // Writing to an engine that has exited would otherwise kill us with SIGPIPE.
        signal(SIGPIPE, SIG_IGN)
    }

    public var isRunning: Bool { process?.isRunning ?? false }

    /// Trims surrounding whitespace and checks the path is an existing,
    /// non-directory, executable file. Returns the resolved URL on success.
    public static func validate(path raw: String) -> Result<URL, LaunchError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyPath) }

        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: trimmed, isDirectory: &isDirectory) else {
            return .failure(.notFound(trimmed))
        }
        if isDirectory.boolValue {
            return .failure(.isDirectory(trimmed))
        }
        guard fm.isExecutableFile(atPath: trimmed) else {
            return .failure(.notExecutable(trimmed))
        }
        return .success(URL(fileURLWithPath: trimmed))
    }

    /// Validates and launches the engine. On success the process is running and
    /// output is being streamed; the caller typically sends "uci" next.
    @discardableResult
    public func start(path raw: String) -> Result<Void, LaunchError> {
        stop()
        switch UCIEngine.validate(path: raw) {
        case .failure(let error):
            return .failure(error)
        case .success(let url):
            let proc = Process()
            proc.executableURL = url
            let outPipe = Pipe()
            let inPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = outPipe
            proc.standardInput = inPipe

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                self?.queue.async { self?.ingest(data) }
            }
            proc.terminationHandler = { [weak self] _ in
                outPipe.fileHandleForReading.readabilityHandler = nil
                self?.onTerminate()
            }

            do {
                try proc.run()
            } catch {
                return .failure(.launchFailed(error.localizedDescription))
            }
            self.process = proc
            self.stdinPipe = inPipe
            return .success(())
        }
    }

    /// Accumulates incoming bytes and emits one callback per complete line.
    /// Runs on `queue`.
    private func ingest(_ data: Data) {
        lineBuffer.append(data)
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let lineData = lineBuffer.subdata(in: lineBuffer.startIndex..<newline)
            lineBuffer.removeSubrange(lineBuffer.startIndex...newline)
            guard var line = String(data: lineData, encoding: .utf8) else { continue }
            if line.hasSuffix("\r") { line.removeLast() }
            if !line.isEmpty { onLine(line) }
        }
    }

    /// Sends one command to the engine (a trailing newline is added if missing).
    public func send(_ command: String) {
        guard let handle = stdinPipe?.fileHandleForWriting else { return }
        let text = command.hasSuffix("\n") ? command : command + "\n"
        guard let data = text.data(using: .utf8) else { return }
        // The engine may have died between checks; ignore broken-pipe writes.
        try? handle.write(contentsOf: data)
    }

    /// Asks the engine to quit, then tears down the process.
    public func stop() {
        if let proc = process, proc.isRunning {
            send("quit")
            proc.terminate()
        }
        process = nil
        stdinPipe = nil
        lineBuffer.removeAll()
    }

    deinit {
        stop()
    }
}
