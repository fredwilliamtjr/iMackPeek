import Foundation

/// Erros específicos da interação com o binário `mackup`.
enum MackupError: Error, LocalizedError {
    case notInstalled
    case unexpectedOutput(String)
    case commandFailed(arguments: [String], exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "O Mackup não está instalado."
        case .unexpectedOutput(let detail):
            return "Saída inesperada do Mackup: \(detail)"
        case .commandFailed(let args, let code, let stderr):
            let cmd = (["mackup"] + args).joined(separator: " ")
            let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Comando falhou (exit \(code)): \(cmd)\n\(tail)"
        }
    }
}

/// Wrapper de alto nível sobre o CLI do Mackup.
///
/// Nunca toca no `~/.mackup.cfg` do usuário: comandos que dependem de config
/// (backup/restore) sempre receberão `-c <arquivo temporário>` nas fases
/// seguintes. Nesta fase expomos apenas `version()` e `list()`, que não
/// dependem de configuração.
final class MackupCLI {

    let executablePath: String
    /// Cache opcional da saída de `show` (configurado após descobrir a versão).
    private var showCache: ShowCache?

    init(executablePath: String) {
        self.executablePath = executablePath
    }

    /// Liga o cache de `show`, atrelado à versão do Mackup.
    func enableShowCache(mackupVersion: String, now: Date) {
        showCache = ShowCache(mackupVersion: mackupVersion, now: now)
    }

    /// Persiste o cache de `show` em disco (chamar ao fim de um scan).
    func flushShowCache() async {
        await showCache?.flush()
    }

    /// Tenta localizar o `mackup` no sistema e devolve uma instância pronta.
    /// Retorna `nil` se o binário não for encontrado.
    static func locate() -> MackupCLI? {
        guard let path = HomebrewDetector.locateMackup() else { return nil }
        return MackupCLI(executablePath: path)
    }

    // MARK: - Comandos

    /// Versão instalada, ex.: "0.10.3" a partir de "Mackup 0.10.3".
    func version() async throws -> String {
        let result = try await execute(["--version"])
        let raw = result.trimmedStdout
        // Formato observado: "Mackup 0.10.3"
        let version = raw
            .replacingOccurrences(of: "Mackup", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !version.isEmpty else {
            throw MackupError.unexpectedOutput(raw)
        }
        return version
    }

    /// Lista os slugs de todos os apps suportados (ex.: "git", "vim").
    func list() async throws -> [String] {
        let result = try await execute(["list"])
        return MackupParser.parseList(result.stdout)
    }

    /// Detalhes de um app: nome legível + caminhos de configuração.
    /// Usa o cache em disco quando disponível e válido (TTL 24h).
    func show(_ slug: String) async throws -> MackupParser.ShowResult {
        if let cached = await showCache?.result(for: slug) {
            return cached
        }
        let result = try await execute(["show", slug])
        let parsed = MackupParser.parseShow(result.stdout, fallbackName: slug)
        await showCache?.store(parsed, for: slug)
        return parsed
    }

    // MARK: - Backup / Restore

    /// Executa `mackup -c <config> [-n] -f backup`.
    ///
    /// `-c` usa a config temporária (nunca a do usuário). `-f` responde "sim"
    /// às confirmações — a confirmação real acontece na UI antes de chamar.
    /// `-n` (dryRun) apenas mostra os passos, sem copiar nada.
    ///
    /// Retorna o `ShellResult` cru (mesmo em falha) para a UI exibir a saída.
    func backup(configPath: URL, dryRun: Bool) async throws -> ShellResult {
        try await runStorageCommand("backup", configPath: configPath, dryRun: dryRun)
    }

    /// Executa `mackup -c <config> [-n] -f restore`.
    func restore(configPath: URL, dryRun: Bool) async throws -> ShellResult {
        try await runStorageCommand("restore", configPath: configPath, dryRun: dryRun)
    }

    private func runStorageCommand(_ command: String, configPath: URL, dryRun: Bool) async throws -> ShellResult {
        var args = ["-c", configPath.path, "-f"]
        if dryRun { args.append("-n") }
        args.append(command)
        return try await Shell.runAsync(executablePath, args)
    }

    // MARK: - Execução

    private func execute(_ arguments: [String]) async throws -> ShellResult {
        let result = try await Shell.runAsync(executablePath, arguments)
        guard result.succeeded else {
            throw MackupError.commandFailed(
                arguments: arguments,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result
    }
}
