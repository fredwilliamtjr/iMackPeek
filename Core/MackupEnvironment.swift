import Foundation
import SwiftUI

/// Estado global do ambiente Mackup, observável pela UI.
///
/// Na Fase 1 ele cumpre três papéis:
///  1. Detectar se o `mackup` está instalado (e onde).
///  2. Validar o pipeline de execução rodando `--version` e `list`.
///  3. Expor o resultado para a UI decidir entre tela de instalação x principal.
@MainActor
final class MackupEnvironment: ObservableObject {

    /// Situação geral do ambiente.
    enum Status: Equatable {
        case checking
        case ready(version: String, supportedCount: Int)
        case notInstalled
        case failed(String)
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var mackupPath: String?
    @Published private(set) var brewPath: String?

    /// Slugs suportados (preenchido quando `status == .ready`).
    @Published private(set) var supportedApps: [String] = []

    /// Config do usuário lida em modo somente-leitura (storage engine, modo).
    @Published private(set) var userConfig = MackupConfig()

    /// Wrapper do CLI, disponível quando o Mackup foi localizado.
    private(set) var cli: MackupCLI?

    /// Executa a detecção + smoke test. Idempotente: pode ser chamado de novo
    /// (ex.: após o usuário instalar o Mackup pela tela de instalação).
    func refresh() async {
        status = .checking
        brewPath = HomebrewDetector.locateBrew()

        guard let cli = MackupCLI.locate() else {
            mackupPath = nil
            self.cli = nil
            status = .notInstalled
            Log.app.notice("mackup não encontrado")
            return
        }

        self.cli = cli
        mackupPath = cli.executablePath
        userConfig = MackupConfig.loadUserConfig() ?? MackupConfig()
        Log.app.notice("mackup localizado em \(cli.executablePath, privacy: .public)")

        do {
            let version = try await cli.version()
            let apps = try await cli.list()
            supportedApps = apps
            status = .ready(version: version, supportedCount: apps.count)
            Log.app.notice("mackup \(version, privacy: .public) — \(apps.count) apps suportados")
        } catch {
            supportedApps = []
            status = .failed(error.localizedDescription)
            Log.app.error("smoke test falhou: \(error.localizedDescription, privacy: .public)")
        }
    }
}
