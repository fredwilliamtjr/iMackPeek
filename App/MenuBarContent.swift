import SwiftUI

/// Conteúdo do ícone da menu bar: abrir a janela, atalhos de perfis e sair.
///
/// Os atalhos de perfil **carregam** o perfil e abrem a janela no modo certo,
/// deixando o usuário confirmar a execução — em vez de disparar backup/restore
/// silenciosamente (operações que sobrescrevem arquivos).
struct MenuBarContent: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Abrir iMackPeek") { openMainWindow() }

        Divider()

        profileSection(title: "Backup", mode: .backup)
        profileSection(title: "Restore", mode: .restore)

        Divider()

        Toggle("Iniciar com o macOS", isOn: $launchAtLogin.isEnabled)

        Button("Sair do iMackPeek") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private func profileSection(title: String, mode: AppMode) -> some View {
        let profiles = app.profiles.profiles(for: mode)
        if profiles.isEmpty {
            Text("\(title): nenhum perfil")
        } else {
            Menu(title) {
                ForEach(profiles) { profile in
                    Button(profile.name) {
                        app.loadProfile(profile)
                        openMainWindow()
                    }
                }
            }
        }
    }

    private func openMainWindow() {
        openWindow(id: iMackPeekApp.mainWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
