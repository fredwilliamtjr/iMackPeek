import AppKit

/// Delegate da aplicação.
///
/// Hoje cuida apenas do comportamento básico de janela. O `NSStatusItem`
/// (atalhos rápidos no menu bar) entra na Fase 4 — ver seção 4.3 do briefing.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app (estilo iCloudPeek / iNetPeek): sem ícone no Dock,
        // vive na barra de menus. A janela é aberta pelo MenuBarExtra.
        NSApp.setActivationPolicy(.accessory)
        Log.app.notice("iMackPeek iniciado")
    }

    /// Mantém o app vivo na menu bar mesmo sem janelas abertas — o ícone na
    /// barra continua disponível para reabrir ou usar atalhos de perfil.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
