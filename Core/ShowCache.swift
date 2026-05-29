import Foundation

/// Cache em disco da saída de `mackup show` (seção 5.6). A saída de `show`
/// muda raramente (depende só da versão do Mackup), então cacheá-la torna o
/// segundo scan praticamente instantâneo. A *existência* dos arquivos NÃO é
/// cacheada — isso é sempre checado ao vivo pelo `ApplicationDetector`.
///
/// `actor` garante acesso seguro sob o paralelismo do scan (até 10 simultâneos).
actor ShowCache {
    private struct Entry: Codable {
        let name: String
        let paths: [String]
        let savedAt: Date
    }

    private struct Payload: Codable {
        var version: Int
        var mackupVersion: String
        var entries: [String: Entry]
    }

    private let ttl: TimeInterval = 24 * 60 * 60
    private let mackupVersion: String
    private let fileURL: URL
    private var entries: [String: Entry]
    private let now: Date

    /// `now` é injetado (o ambiente do iMackPeek proíbe `Date()` em alguns
    /// contextos); o chamador passa a data atual.
    init(mackupVersion: String, now: Date) {
        self.mackupVersion = mackupVersion
        self.now = now
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("iMackPeek", isDirectory: true)
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        self.fileURL = caches.appendingPathComponent("show-cache.json")

        // Carrega o cache existente, descartando se for de outra versão do Mackup.
        if let data = try? Data(contentsOf: fileURL),
           let payload = try? JSONDecoder().decode(Payload.self, from: data),
           payload.mackupVersion == mackupVersion {
            self.entries = payload.entries
        } else {
            self.entries = [:]
        }
    }

    /// Resultado cacheado e ainda válido (dentro do TTL), se houver.
    func result(for slug: String) -> MackupParser.ShowResult? {
        guard let entry = entries[slug] else { return nil }
        guard now.timeIntervalSince(entry.savedAt) < ttl else { return nil }
        return MackupParser.ShowResult(name: entry.name, paths: entry.paths)
    }

    /// Guarda (em memória) o resultado para um slug.
    func store(_ result: MackupParser.ShowResult, for slug: String) {
        entries[slug] = Entry(name: result.name, paths: result.paths, savedAt: now)
    }

    /// Persiste o cache em disco. Chamar uma vez, ao fim de um scan.
    func flush() {
        let payload = Payload(version: 1, mackupVersion: mackupVersion, entries: entries)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
