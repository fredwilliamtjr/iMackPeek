import AppKit

/// Delegate da aplicação.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App de barra de menus: o estado inicial "acessório" (sem Dock) vem do
        // LSUIElement no Info.plist. Não há janela no launch (início silencioso)
        // — ela é criada sob demanda pelo WindowManager. A presença no Dock é
        // dinâmica: aparece com a janela aberta, some quando fecha.
        Log.app.notice("iMackPeek iniciado")
    }

    /// Mantém o app vivo na barra de menus mesmo sem janelas abertas.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
