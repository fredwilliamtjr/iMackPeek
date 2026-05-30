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
            let tail = stderr.strippingANSI().trimmingCharacters(in: .whitespacesAndNewlines)
            return "Comando falhou (exit \(code)): \(cmd)\n\(tail)"
        }
    }
}

/// Wrapper de alto nível sobre o CLI do Mackup.
///
/// Nunca toca no `~/.mackup.cfg` do usuário. Todo comando que precisa de um
/// storage engine recebe `-c <arquivo temporário>`: `backup`/`restore` usam o
/// config gerado a partir da seleção; `list`/`show` usam um config **neutro**
/// (engine local) — ver `neutralConfig()` — para funcionarem mesmo numa
/// máquina virgem, sem `~/.mackup.cfg`. Só `version()` dispensa config.
final class MackupCLI {

    let executablePath: String
    /// Cache opcional da saída de `show` (configurado após descobrir a versão).
    private var showCache: ShowCache?
    /// Config neutro (engine local) reutilizado por `list`/`show`. Ver `neutralConfig()`.
    private var neutralConfigURL: URL?

    init(executablePath: String) {
        self.executablePath = executablePath
    }

    /// Devolve (criando uma vez) um `.mackup.cfg` **neutro** usado só por
    /// `list`/`show`, que não dependem de storage real.
    ///
    /// Por quê: o Mackup 0.10.3 exige um storage engine resolvível **até em
    /// `list`** — sem `~/.mackup.cfg` ele assume o default (Dropbox) e aborta
    /// com "Unable to find your Dropbox install" numa máquina virgem. Usamos o
    /// engine `file_system` apontando para uma pasta oculta que garantimos
    /// existir, então `list`/`show` funcionam mesmo antes de o usuário
    /// configurar o storage de verdade. Nunca tocamos no `~/.mackup.cfg` dele.
    private func neutralConfig() throws -> URL {
        if let neutralConfigURL { return neutralConfigURL }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        // Pasta de storage do engine file_system (path é relativo ao HOME).
        let storageDir = home.appendingPathComponent(".imackpeek-neutral")
        try fm.createDirectory(at: storageDir, withIntermediateDirectories: true)
        // O Mackup recusa `-c` fora do HOME, então o cfg também fica no home.
        let cfg = home.appendingPathComponent(".imackpeek-neutral.cfg")
        let text = """
        # Config neutro do iMackPeek (list/show) — não reflete o storage do usuário.
        [storage]
        engine = file_system
        path = .imackpeek-neutral

        [mode]
        mode = copy
        """
        try text.write(to: cfg, atomically: true, encoding: .utf8)
        neutralConfigURL = cfg
        return cfg
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
        let cfg = try neutralConfig()
        let result = try await execute(["-c", cfg.path, "list"])
        return MackupParser.parseList(result.stdout)
    }

    /// Detalhes de um app: nome legível + caminhos de configuração.
    /// Usa o cache em disco quando disponível e válido (TTL 24h).
    func show(_ slug: String) async throws -> MackupParser.ShowResult {
        if let cached = await showCache?.result(for: slug) {
            return cached
        }
        let cfg = try neutralConfig()
        let result = try await execute(["-c", cfg.path, "show", slug])
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
