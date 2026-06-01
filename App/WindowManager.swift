import AppKit
import SwiftUI

/// Cria e gerencia a janela principal **sob demanda**.
///
/// O app não usa `WindowGroup` (que sempre abre uma janela no launch e causava
/// o "piscar"). Em vez disso, o app sobe só com o `MenuBarExtra`, e esta classe
/// cria a janela via AppKit (`NSHostingController`) só quando o usuário clica em
/// "Abrir iMackPeek". Resultado: **início 100% silencioso, sem piscar**, em
/// qualquer versão do macOS.
///
/// Também controla a presença no Dock: ao mostrar a janela vira `.regular`
/// (ícone no Dock), ao fechar volta a `.accessory` (só barra de menus).
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private var window: NSWindow?
    private override init() {}

    /// Abre (ou traz pra frente) a janela principal.
    func showMainWindow() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: MainWindowView().environmentObject(AppModel.shared)
            )
            let win = NSWindow(contentViewController: hosting)
            win.title = "iMackPeek"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.minSize = NSSize(width: 760, height: 520)
            win.setContentSize(NSSize(width: 860, height: 580))
            win.isReleasedWhenClosed = false
            win.isRestorable = false
            win.center()
            win.delegate = self
            window = win
        }
        DockPresence.showInDock()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Janela fechada → some do Dock, volta a ser só barra de menus.
        DockPresence.hideFromDock()
    }
}
