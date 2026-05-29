import Foundation

/// Representação leve do `.mackup.cfg` (formato INI).
///
/// O iMackPeek **lê** o `~/.mackup.cfg` do usuário apenas para descobrir o
/// storage engine e o modo configurados — nunca o modifica (seção 5.1). Toda
/// escrita acontece em arquivos temporários gerados pelo `ConfigGenerator`.
struct MackupConfig: Equatable {
    /// Engine de storage: "icloud", "dropbox", "google_drive", "box", "file".
    var storageEngine: String?
    /// Diretório (usado quando engine = "file") — chave `directory`.
    var storageDirectory: String?
    /// Caminho relativo dentro do storage — chave `path`.
    var storagePath: String?
    /// Modo: "copy" ou "link". iMackPeek sempre força "copy" ao gerar config.
    var mode: String?

    /// Engine efetivo para exibição/uso, com fallback para iCloud.
    var effectiveEngine: String { storageEngine ?? "icloud" }

    static let userConfigURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".mackup.cfg")

    /// Lê e faz parse do `~/.mackup.cfg`, se existir. Somente leitura.
    static func loadUserConfig() -> MackupConfig? {
        guard let text = try? String(contentsOf: userConfigURL, encoding: .utf8) else {
            return nil
        }
        return parse(text)
    }

    /// Parser tolerante de INI: reconhece `[secao]` e `chave = valor`,
    /// ignora comentários (`#`, `;`) e espaços.
    static func parse(_ text: String) -> MackupConfig {
        var config = MackupConfig()
        var section = ""

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = line.dropFirst().dropLast().lowercased()
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)

            switch (section, key) {
            case ("storage", "engine"): config.storageEngine = value
            case ("storage", "directory"): config.storageDirectory = value
            case ("storage", "path"): config.storagePath = value
            case ("mode", "mode"): config.mode = value
            default: break
            }
        }
        return config
    }
}
