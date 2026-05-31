import XCTest

final class EngineOptionStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "EngineOptionStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSetAndGetRoundTrip() {
        let store = EngineOptionStore(defaults: defaults)
        store.setOption("Hash", value: "256", forPath: "/bin/engine")
        store.setOption("Threads", value: "4", forPath: "/bin/engine")
        XCTAssertEqual(store.options(forPath: "/bin/engine"), ["Hash": "256", "Threads": "4"])
    }

    func testPerPathIsolation() {
        let store = EngineOptionStore(defaults: defaults)
        store.setOption("Hash", value: "256", forPath: "/a")
        store.setOption("Hash", value: "16", forPath: "/b")
        XCTAssertEqual(store.options(forPath: "/a"), ["Hash": "256"])
        XCTAssertEqual(store.options(forPath: "/b"), ["Hash": "16"])
    }

    func testClearWithNil() {
        let store = EngineOptionStore(defaults: defaults)
        store.setOption("Hash", value: "256", forPath: "/a")
        store.setOption("Hash", value: nil, forPath: "/a")
        XCTAssertTrue(store.options(forPath: "/a").isEmpty)
    }

    func testPersistsAcrossInstances() {
        EngineOptionStore(defaults: defaults).setOption("Ponder", value: "true", forPath: "/a")
        let reread = EngineOptionStore(defaults: defaults)
        XCTAssertEqual(reread.options(forPath: "/a")["Ponder"], "true")
    }

    func testEmptyPathIsIgnored() {
        let store = EngineOptionStore(defaults: defaults)
        store.setOption("Hash", value: "256", forPath: "")
        XCTAssertTrue(store.options(forPath: "").isEmpty)
    }
}
