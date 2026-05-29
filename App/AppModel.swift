import Foundation
import SwiftUI

/// Coordenador central do app, compartilhado entre a UI e a menu bar.
///
/// Mantém uma única instância dos view models de Backup e Restore (para que
/// perfis e atalhos da menu bar operem sobre o mesmo estado) além do ambiente
/// Mackup e do armazenamento de perfis.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let environment = MackupEnvironment()
    let backup = BackupViewModel()
    let restore = RestoreViewModel()
    let profiles = ProfileStore()

    @Published var mode: AppMode = .backup

    private init() {}

    /// Inicialização: detecta o Mackup e liga o cache de `show`.
    func bootstrap() async {
        await environment.refresh()
        if case .ready(let version, _) = environment.status, let cli = environment.cli {
            cli.enableShowCache(mackupVersion: version, now: Date())
        }
    }

    // MARK: - Perfis

    /// Aplica um perfil: muda de modo e seleciona os apps correspondentes.
    func loadProfile(_ profile: Profile) {
        mode = profile.mode
        switch profile.mode {
        case .backup:
            backup.applySelection(Set(profile.apps))
        case .restore:
            restore.applySelection(Set(profile.apps))
            restore.restartDaemons = profile.restartDaemons
        case .profiles:
            break
        }
    }

    /// Cria um perfil a partir da seleção atual do modo ativo.
    func makeProfile(name: String) -> Profile? {
        switch mode {
        case .backup:
            return Profile(name: name, mode: .backup,
                           apps: Array(backup.selection).sorted(), restartDaemons: false)
        case .restore:
            return Profile(name: name, mode: .restore,
                           apps: Array(restore.selection).sorted(), restartDaemons: restore.restartDaemons)
        case .profiles:
            return nil
        }
    }
}
