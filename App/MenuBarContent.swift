import SwiftUI

/// Conteúdo do ícone da barra de menu: versão, abrir a janela, iniciar com o
/// macOS e sair.
struct MenuBarContent: View {
    @ObservedObject private var launchAtLogin = LaunchAtLogin.shared

    var body: some View {
        Text("iMackPeek \(AppInfo.versionWithBuild)")

        Divider()

        Button("Abrir iMackPeek") { WindowManager.shared.showMainWindow() }

        Divider()

        Toggle("Iniciar com o macOS", isOn: $launchAtLogin.isEnabled)

        Button("Sair do iMackPeek") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
