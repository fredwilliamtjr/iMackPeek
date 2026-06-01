import AppKit

/// Controla a presença do iMackPeek no Dock.
///
/// O app é um menu bar app (`LSUIElement`/`.accessory`) — normalmente sem
/// ícone no Dock. Para a experiência que o Fred quer, alternamos a política
/// dinamicamente: **com a janela aberta** o app vira `.regular` (aparece no
/// Dock e no Cmd+Tab); **ao fechar a janela** volta a `.accessory` (some do
/// Dock, fica só na barra de menus).
enum DockPresence {

    /// Mostra o ícone no Dock e traz o app pra frente. Chamado quando a janela
    /// principal aparece.
    static func showInDock() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Esconde o ícone do Dock. Chamado quando a janela principal fecha.
    static func hideFromDock() {
        guard NSApp.activationPolicy() != .accessory else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
