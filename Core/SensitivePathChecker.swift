import Foundation

/// Identifica caminhos sensíveis (credenciais, chaves) entre os arquivos de um
/// app, para destacar com aviso na UI (seção 5.3). A lista vem de
/// `known-sensitive-paths.json` no bundle.
struct SensitivePathChecker {
    let sensitivePrefixes: [String]

    /// Carrega a lista do bundle. Em caso de falha, usa um fallback mínimo
    /// embutido para nunca deixar o usuário sem aviso de `.ssh`/`.aws`.
    static func loadFromBundle() -> SensitivePathChecker {
        guard let url = Bundle.main.url(forResource: "known-sensitive-paths", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else {
            Log.app.error("known-sensitive-paths.json não encontrado — usando fallback")
            return SensitivePathChecker(sensitivePrefixes: [".ssh/", ".aws/", ".gnupg/", ".netrc"])
        }
        return SensitivePathChecker(sensitivePrefixes: list)
    }

    /// Dentre `paths` (relativos ao home), devolve os que casam com algum
    /// padrão sensível. O casamento é por prefixo, tolerante a barra final.
    func sensitiveMatches(in paths: [String]) -> [String] {
        paths.filter { path in
            sensitivePrefixes.contains { pattern in matches(path: path, pattern: pattern) }
        }
    }

    private func matches(path: String, pattern: String) -> Bool {
        // Padrão terminado em "/" = diretório: casa o próprio dir ou conteúdo.
        if pattern.hasSuffix("/") {
            let dir = String(pattern.dropLast())
            return path == dir || path.hasPrefix(pattern)
        }
        // Padrão de arquivo: casa exato ou como prefixo de caminho mais fundo.
        return path == pattern || path.hasPrefix(pattern + "/")
    }
}
