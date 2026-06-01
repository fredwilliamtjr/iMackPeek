import Foundation

/// Aplica ao Finder **vivo** as configs que `CFPreferences` sozinho não muda:
/// as barras (caminho / status / lateral). Aciona o menu Visualizar via
/// AppleScript — o equivalente programático a "mandar exibir" na mão, que foi
/// a única coisa que provamos funcionar. Ver a memória `finder-sync-mechanism`.
///
/// - A **barra de status** usa propriedade de janela (`statusbar visible`) e
///   **não** exige permissão extra.
/// - A **barra de caminho** e a **lateral** acionam itens do menu via System
///   Events e exigem permissão de **Acessibilidade**. Se faltar, o script
///   devolve `BLOQUEADO` e o app orienta o usuário.
enum FinderUIApplier {

    struct Desired {
        let pathbar: Bool?
        let statusbar: Bool?
        let sidebar: Bool?
        let tabbar: Bool?

        var isEmpty: Bool { pathbar == nil && statusbar == nil && sidebar == nil && tabbar == nil }
    }

    /// Extrai os estados desejados do snapshot do domínio `com.apple.finder`.
    static func desired(fromFinderDomain values: [String: Any]?) -> Desired {
        func b(_ k: String) -> Bool? {
            guard let n = values?[k] as? NSNumber else { return nil }
            return n.boolValue
        }
        return Desired(pathbar: b("ShowPathbar"),
                       statusbar: b("ShowStatusBar"),
                       sidebar: b("ShowSidebar"),
                       tabbar: b("NSWindowTabbingShoudShowTabBarKey-com.apple.finder.TBrowserWindow"))
    }

    /// Resultado da aplicação: `ok` ou bloqueio por falta de Acessibilidade.
    enum Result {
        case ok(String)
        case needsAccessibility
        case failed(String)
    }

    /// Aciona o Finder para refletir os estados desejados.
    static func apply(_ d: Desired) async -> Result {
        guard !d.isEmpty else { return .ok("nada a acionar") }
        do {
            let r = try await Shell.runAsync("/usr/bin/osascript", ["-e", buildScript(d)])
            let out = (r.stdout + "\n" + r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            if out.contains("BLOQUEADO") { return .needsAccessibility }
            if !r.succeeded { return .failed(out) }
            return .ok(out.isEmpty ? "barras aplicadas" : out)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - AppleScript

    /// Monta o script AppleScript inteiro (handlers + chamadas) num único texto,
    /// passado ao `osascript` via um único `-e`. Newlines embutidos são aceitos.
    static func buildScript(_ d: Desired) -> String {
        var lines: [String] = []
        lines.append("""
        tell application "Finder"
          activate
          if (count of Finder windows) is 0 then
            make new Finder window to (path to home folder)
          end if
        end tell
        delay 0.4
        """)
        if let sb = d.statusbar {
            lines.append("""
            tell application "Finder" to try
              set statusbar visible of front Finder window to \(sb ? "true" : "false")
            end try
            """)
        }
        if let pb = d.pathbar {
            lines.append(menuToggleSubroutineCall(keywords: ["Caminho", "Path"], wantVisible: pb))
        }
        if let sd = d.sidebar {
            lines.append(menuToggleSubroutineCall(keywords: ["Lateral", "Sidebar"], wantVisible: sd))
        }
        if let tb = d.tabbar {
            // "Barra de Abas" (não confundir com "Mostrar Todas as Abas")
            lines.append(menuToggleSubroutineCall(keywords: ["Barra de Abas", "Tab Bar"], wantVisible: tb))
        }
        lines.append("return \"ok\"")
        return lines.joined(separator: "\n") + "\n" + menuToggleHandler
    }

    /// Chamada do handler que garante um item de menu Visualizar no estado certo.
    private static func menuToggleSubroutineCall(keywords: [String], wantVisible: Bool) -> String {
        let list = keywords.map { "\"\($0)\"" }.joined(separator: ", ")
        return "my ensureMenuToggle({\(list)}, \(wantVisible ? "true" : "false"))"
    }

    /// Handler AppleScript: acha no menu Visualizar o item cujo nome contém
    /// um dos `keywords` e clica se necessário para chegar ao estado desejado.
    /// Detecta o estado pelo prefixo do nome: "Mostrar"/"Show" = oculto;
    /// "Ocultar"/"Hide" = visível.
    private static let menuToggleHandler = """

    on ensureMenuToggle(keywords, wantVisible)
      tell application "System Events"
        if not (UI elements enabled) then return "BLOQUEADO"
        tell process "Finder"
          set vm to menu "Visualizar" of menu bar 1
          repeat with mi in (menu items of vm)
            try
              set nm to name of mi
              repeat with kw in keywords
                if nm contains kw then
                  set isHidden to (nm starts with "Mostrar") or (nm starts with "Show")
                  set isVisible to (nm starts with "Ocultar") or (nm starts with "Hide")
                  if wantVisible and isHidden then click mi
                  if (not wantVisible) and isVisible then click mi
                  return "ok"
                end if
              end repeat
            end try
          end repeat
        end tell
      end tell
      return "ok"
    end ensureMenuToggle
    """
}
