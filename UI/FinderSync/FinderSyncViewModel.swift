import Foundation
import SwiftUI

/// Orquestra o modo "Finder": salva todas as configurações do Finder desta
/// máquina na nuvem e aplica na outra. Usa `SystemPrefsSync` (CFPreferences,
/// para a maioria das configs) + `FinderUIApplier` (AppleScript, para as
/// barras vivas) + `killall` para o Finder reler. Ver memória
/// `finder-sync-mechanism`.
@MainActor
final class FinderSyncViewModel: ObservableObject {

    @Published private(set) var isRunning = false
    @Published var output: ActionOutput?
    /// Info do snapshot que está hoje na nuvem (se houver).
    @Published private(set) var cloudInfo: String?
    @Published private(set) var storageReady = false
    @Published private(set) var storagePath = ""

    private let recipe = SystemPrefsCatalog.finder
    private var sync: SystemPrefsSync?

    var hostName: String { Host.current().localizedName ?? "este Mac" }

    // MARK: - Setup

    func configure() {
        let s = SystemPrefsSync(storageRoot: CloudStorage.root())
        sync = s
        storageReady = true
        storagePath = s.fileURL.path
        if !CloudStorage.isICloudAvailable {
            storagePath += "  (⚠️ iCloud Drive indisponível — não vai sincronizar entre Macs)"
        }
        refreshCloudInfo()
    }

    func refreshCloudInfo() {
        guard let sync else { cloudInfo = nil; return }
        if let snap = try? sync.load() {
            let by = snap.savedBy ?? "desconhecido"
            let when = snap.savedAt.map { Self.dateFmt.string(from: $0) } ?? "data?"
            cloudInfo = "\(snap.totalKeys) configs salvas por “\(by)” em \(when)"
        } else {
            cloudInfo = nil
        }
    }

    // MARK: - Salvar (backup)

    func save() async {
        guard let sync else { return }
        isRunning = true; defer { isRunning = false }
        let snapshot = sync.capture(recipe)
        let total = snapshot.values.reduce(0) { $0 + $1.count }
        do {
            let url = try sync.save(snapshot, hostName: hostName, date: Date())
            refreshCloudInfo()
            output = ActionOutput(
                title: "Configurações do Finder salvas",
                text: "\(total) configurações lidas deste Mac e salvas na nuvem.\n\nArquivo: \(url.path)\n\nAgora, no outro Mac, abra o iMackPeek e clique em “Aplicar”.",
                succeeded: true)
        } catch {
            output = ActionOutput(title: "Falha ao salvar", text: error.localizedDescription,
                                  succeeded: false)
        }
    }

    // MARK: - Excluir sincronização da nuvem

    func deleteSync() async {
        guard let sync else { return }
        isRunning = true; defer { isRunning = false }
        do {
            let removed = try sync.deleteSnapshot()
            refreshCloudInfo()
            output = ActionOutput(
                title: removed ? "Sincronização excluída" : "Nada para excluir",
                text: removed
                    ? "O arquivo de configurações do Finder foi removido da nuvem.\n\nSuas configurações locais do Finder NÃO foram alteradas — só apaguei a cópia salva. Você pode clicar em “Salvar” de novo quando quiser."
                    : "Não havia configurações salvas na nuvem.",
                succeeded: true)
        } catch {
            output = ActionOutput(title: "Falha ao excluir", text: error.localizedDescription, succeeded: false)
        }
    }

    // MARK: - Aplicar (restore)

    func apply() async {
        guard let sync else { return }
        isRunning = true; defer { isRunning = false }

        guard let snap = try? sync.load() else {
            output = ActionOutput(
                title: "Nada para aplicar",
                text: "Não há configurações do Finder salvas na nuvem ainda.\nSalve primeiro em outro Mac.\n\nProcurado em: \(sync.fileURL.path)",
                succeeded: false)
            return
        }

        // 1) grava todas as configs via CFPreferences
        let applied = sync.apply(snap, recipe: recipe)

        // 2) força os daemons a relerem (cfprefsd = cache; Finder e
        //    WindowManager = quem desenha janelas e a Mesa)
        _ = try? await Shell.runAsync("/usr/bin/killall", ["cfprefsd"])
        for daemon in recipe.daemons {
            _ = try? await Shell.runAsync("/usr/bin/killall", [daemon])
        }
        try? await Task.sleep(nanoseconds: 800_000_000)

        // 3) aplica as barras vivas via AppleScript
        let desired = FinderUIApplier.desired(fromFinderDomain: snap.domains["com.apple.finder"])
        let uiResult = await FinderUIApplier.apply(desired)

        var text = "\(applied) configurações aplicadas neste Mac (vindas de “\(snap.savedBy ?? "?")”).\nFinder reiniciado."
        var ok = true
        switch uiResult {
        case .ok(let s):
            text += "\nBarras aplicadas (\(s))."
        case .needsAccessibility:
            ok = false
            text += "\n\n⚠️ A barra de caminho/lateral precisa de permissão de Acessibilidade. "
                + "Vá em Ajustes do Sistema ▸ Privacidade e Segurança ▸ Acessibilidade e ligue o iMackPeek, depois clique em Aplicar de novo."
        case .failed(let e):
            text += "\n\nAviso: não consegui acionar as barras pelo Finder: \(e)"
        }

        output = ActionOutput(title: "Configurações do Finder aplicadas", text: text,
                              succeeded: ok)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()
}
