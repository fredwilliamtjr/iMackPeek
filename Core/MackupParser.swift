import Foundation

/// Parser da saída textual do `mackup`.
///
/// É deliberadamente *tolerante*: o Mackup pode mudar pequenas coisas de
/// formatação entre versões (seção 5.5 do briefing). Em vez de casar a saída
/// linha-a-linha de forma rígida, reconhecemos o padrão de item de lista
/// (` - <valor>`) e ignoramos cabeçalhos/linhas em branco.
enum MackupParser {

    /// Prefixos de itens de lista observados na saída do Mackup.
    /// Cobrimos "- ", "* " e variações com indentação.
    private static let bulletPrefixes = ["- ", "* "]

    /// Faz parse de `mackup list`.
    ///
    /// Saída real (0.10.3):
    /// ```
    /// Supported applications:
    ///  - 1password-4
    ///  - 2do
    ///  - ack
    /// ```
    /// Devolve apenas os slugs, ordenados e sem duplicatas.
    static func parseList(_ output: String) -> [String] {
        var slugs: [String] = []
        var seen = Set<String>()

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let value = bulletValue(in: String(rawLine)) else { continue }
            let slug = value.trimmingCharacters(in: .whitespaces)
            guard !slug.isEmpty, !seen.contains(slug) else { continue }
            seen.insert(slug)
            slugs.append(slug)
        }
        return slugs
    }

    /// Resultado do parse de `mackup show <app>`.
    struct ShowResult: Equatable {
        let name: String        // nome legível (ex.: "Git")
        let paths: [String]     // caminhos relativos ao home
    }

    /// Faz parse de `mackup show <app>`.
    ///
    /// Saída real (0.10.3):
    /// ```
    /// Name: Git
    /// Configuration files:
    ///  - .config/git/ignore
    ///  - .gitconfig
    /// ```
    /// `fallbackName` é usado caso a linha "Name:" não apareça (tolerância a
    /// mudanças de formato). Caminhos vêm como itens de lista, sejam arquivos
    /// ou pastas — o Mackup não distingue na saída.
    static func parseShow(_ output: String, fallbackName: String) -> ShowResult {
        var name: String?
        var paths: [String] = []
        var seen = Set<String>()

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if name == nil, let value = headerValue(in: trimmed, key: "Name") {
                name = value
                continue
            }
            if let value = bulletValue(in: line) {
                let path = value.trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty, !seen.contains(path) else { continue }
                seen.insert(path)
                paths.append(path)
            }
        }

        return ShowResult(name: name ?? fallbackName, paths: paths)
    }

    // MARK: - Helpers

    /// Se a linha for "Chave: valor", devolve "valor"; senão `nil`.
    private static func headerValue(in line: String, key: String) -> String? {
        let prefix = "\(key):"
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    /// Se a linha for um item de lista (` - foo`), devolve "foo"; senão `nil`.
    private static func bulletValue(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for prefix in bulletPrefixes where trimmed.hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count))
        }
        return nil
    }
}
