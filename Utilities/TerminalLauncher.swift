import AppKit
import Foundation

/// Abre o Terminal.app e executa um comando. Usado para instalações que
/// precisam de TTY interativo / senha de sudo (ex.: instalar o Homebrew),
/// onde rodar via `Process` silenciosamente não funcionaria.
enum TerminalLauncher {

    /// Executa `command` em uma nova janela do Terminal. Retorna `false` se o
    /// AppleScript falhar.
    @discardableResult
    static func run(_ command: String) -> Bool {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        script.executeAndReturnError(&error)
        if let error {
            Log.app.error("TerminalLauncher falhou: \(error.description, privacy: .public)")
            return false
        }
        return true
    }
}
