import XCTest

final class UCIEngineTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ChessUITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func writeFile(_ name: String, contents: String, executable: Bool) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        if executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } else {
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        }
        return url
    }

    // MARK: - Path validation

    func testValidateEmptyAndWhitespacePath() {
        XCTAssertEqual(UCIEngine.validate(path: ""), .failure(.emptyPath))
        XCTAssertEqual(UCIEngine.validate(path: "    \t  "), .failure(.emptyPath))
    }

    func testValidateMissingFile() {
        let missing = tempDir.appendingPathComponent("nope").path
        XCTAssertEqual(UCIEngine.validate(path: missing), .failure(.notFound(missing)))
    }

    func testValidateDirectory() {
        XCTAssertEqual(UCIEngine.validate(path: tempDir.path), .failure(.isDirectory(tempDir.path)))
    }

    func testValidateNonExecutableFile() throws {
        let url = try writeFile("plain.txt", contents: "hello", executable: false)
        XCTAssertEqual(UCIEngine.validate(path: url.path), .failure(.notExecutable(url.path)))
    }

    func testValidateTrimsWhitespaceAndAcceptsExecutable() throws {
        let url = try writeFile("engine.sh", contents: "#!/bin/bash\n", executable: true)
        // Surrounding whitespace must be trimmed before validation.
        let result = UCIEngine.validate(path: "   \(url.path)\t ")
        switch result {
        case .success(let resolved):
            XCTAssertEqual(resolved.path, url.path)
        case .failure(let error):
            XCTFail("expected success, got \(error)")
        }
    }

    // MARK: - Live handshake against a mock engine

    private func writeMockEngine() throws -> URL {
        let script = """
        #!/bin/bash
        while IFS= read -r line; do
          case "$line" in
            uci)
              printf 'id name MockEngine 1.2\\n'
              printf 'id author ChessUI Tests\\n'
              printf 'option name Hash type spin default 16 min 1 max 1024\\n'
              printf 'option name Ponder type check default false\\n'
              printf 'uciok\\n'
              ;;
            isready) printf 'readyok\\n' ;;
            quit) exit 0 ;;
          esac
        done
        """
        return try writeFile("mock-engine.sh", contents: script, executable: true)
    }

    func testHandshakeReceivesIdOptionsAndReadyok() throws {
        let engineURL = try writeMockEngine()

        let lock = NSLock()
        var lines: [String] = []
        let sawUCIOK = expectation(description: "uciok")
        let sawReadyOK = expectation(description: "readyok")

        let engine = UCIEngine(onLine: { line in
            lock.lock()
            lines.append(line)
            lock.unlock()
            if line == "uciok" { sawUCIOK.fulfill() }
            if line == "readyok" { sawReadyOK.fulfill() }
        })

        // Pass a padded path to also exercise trimming in start().
        switch engine.start(path: "  \(engineURL.path) ") {
        case .failure(let error):
            return XCTFail("engine failed to start: \(error)")
        case .success:
            break
        }

        engine.send("uci")
        wait(for: [sawUCIOK], timeout: 5)
        engine.send("isready")
        wait(for: [sawReadyOK], timeout: 5)

        lock.lock()
        let received = lines
        lock.unlock()
        engine.stop()

        XCTAssertTrue(received.contains("id name MockEngine 1.2"))
        XCTAssertTrue(received.contains("id author ChessUI Tests"))
        XCTAssertTrue(received.contains { UCIProtocol.parseOption($0)?.name == "Hash" })

        // Parsing the collected lines yields the expected identity/options.
        let names = received.compactMap { UCIProtocol.parseID($0) }
            .filter { $0.0 == .name }.map { $0.1 }
        XCTAssertEqual(names, ["MockEngine 1.2"])
        let options = received.compactMap { UCIProtocol.parseOption($0) }
        XCTAssertEqual(options.count, 2)
    }

    /// End-to-end against a real engine if one is installed on this machine.
    /// Skipped otherwise so the suite stays portable.
    func testRealEngineAnalysisIfAvailable() throws {
        let candidates = ["/usr/local/bin/stockfish", "/opt/homebrew/bin/stockfish"]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw XCTSkip("No Stockfish binary found; skipping real-engine test.")
        }

        let lock = NSLock()
        var lines: [String] = []
        let ready = expectation(description: "readyok")
        let gotBestMove = expectation(description: "bestmove")

        let engine = UCIEngine(onLine: { line in
            lock.lock(); lines.append(line); lock.unlock()
            if line == "readyok" { ready.fulfill() }
            if UCIProtocol.parseBestMove(line) != nil { gotBestMove.fulfill() }
        })

        try engine.start(path: path).get()
        engine.send("uci")
        engine.send("isready")
        wait(for: [ready], timeout: 10)

        engine.send("position startpos")
        engine.send("go movetime 800")
        wait(for: [gotBestMove], timeout: 10)

        lock.lock(); let received = lines; lock.unlock()
        engine.stop()

        // Identity, at least one scored info line, and a best move.
        XCTAssertTrue(received.contains { UCIProtocol.parseID($0)?.0 == .name })
        XCTAssertTrue(received.contains { line in
            guard let info = UCIProtocol.parseInfo(line) else { return false }
            return info.scoreCentipawns != nil || info.scoreMate != nil
        })
        XCTAssertNotNil(received.compactMap { UCIProtocol.parseBestMove($0) }.first)
    }

    func testStopTerminatesProcess() throws {
        let engineURL = try writeMockEngine()
        let engine = UCIEngine(onLine: { _ in })
        XCTAssertNoThrow(try engine.start(path: engineURL.path).get())
        XCTAssertTrue(engine.isRunning)
        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }
}
