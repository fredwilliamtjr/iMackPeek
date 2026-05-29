import Foundation

/// Resultado da execução de um processo externo.
struct ShellResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { exitCode == 0 }

    /// stdout sem espaços/quebras nas pontas — conveniência para parsing.
    var trimmedStdout: String {
        stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ShellError: Error, LocalizedError {
    case executableNotFound(String)
    case launchFailed(path: String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executável não encontrado: \(path)"
        case .launchFailed(let path, let underlying):
            return "Falha ao iniciar \(path): \(underlying)"
        }
    }
}

/// Abstração genérica sobre `Process`. Toda chamada de binário externo do
/// iMackPeek passa por aqui — facilita logging, tratamento de erro e testes.
///
/// As funções de execução são *bloqueantes*; use `runAsync` a partir da UI
/// para não travar a main thread.
enum Shell {

    /// Executa `executable` com `arguments` e devolve o resultado completo.
    /// Lê stdout/stderr até o fim antes de aguardar o término, evitando
    /// deadlock quando a saída é grande (ex.: `mackup list` com 600+ linhas).
    static func run(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String]? = nil
    ) throws -> ShellResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ShellError.executableNotFound(executable)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        Log.shell.debug("run: \(executable, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(path: executable, underlying: error.localizedDescription)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let result = ShellResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
        Log.shell.debug("exit=\(result.exitCode, privacy: .public)")
        return result
    }

    /// Versão assíncrona: roda o processo fora da main thread.
    static func runAsync(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> ShellResult {
        try await Task.detached(priority: .userInitiated) {
            try Shell.run(executable, arguments, environment: environment)
        }.value
    }
}
