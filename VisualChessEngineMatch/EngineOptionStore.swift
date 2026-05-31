import Foundation

/// Persists user-chosen UCI option values per engine binary path, so they can
/// be replayed when the same engine is reconnected.
///
/// Stored as JSON under a single `UserDefaults` key:
/// `{ "<engine path>": { "<option name>": "<value>" } }`.
struct EngineOptionStore {
    private let defaults: UserDefaults
    private let key = "engineOptionValues"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func loadAll() -> [String: [String: String]] {
        guard let data = defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else { return [:] }
        return dict
    }

    private func saveAll(_ dict: [String: [String: String]]) {
        defaults.set(try? JSONEncoder().encode(dict), forKey: key)
    }

    /// All saved option values for the engine at `path`.
    func options(forPath path: String) -> [String: String] {
        loadAll()[path] ?? [:]
    }

    /// Saves (or, with a nil value, clears) one option value for `path`.
    func setOption(_ name: String, value: String?, forPath path: String) {
        guard !path.isEmpty else { return }
        var all = loadAll()
        var perPath = all[path] ?? [:]
        if let value { perPath[name] = value } else { perPath.removeValue(forKey: name) }
        all[path] = perPath
        saveAll(all)
    }
}
