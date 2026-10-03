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
    /// Pastas de nuvem encontradas neste Mac (opções do seletor).
    @Published private(set) var locations: [CloudLocation] = []
    /// Pasta de nuvem em uso; `nil` = gravando só localmente.
    @Published private(set) var selectedLocation: CloudLocation?
    /// Serviços suportados que não estão instalados neste Mac.
    @Published private(set) var missingServices: [CloudService] = []
    /// Aviso quando o arquivo não vai sincronizar entre Macs.
    @Published private(set) var storageWarning: String?

    private let recipe = SystemPrefsCatalog.finder
    private var sync: SystemPrefsSync?

    var hostName: String { Host.current().localizedName ?? "este Mac" }

    /// Nome do destino para as mensagens ("iCloud Drive", "Google Drive (…)").
    var destinationName: String { selectedLocation?.displayName ?? "este Mac (local)" }

    // MARK: - Setup

    func configure() {
        locations = CloudStorage.available()
        missingServices = CloudStorage.missingServices(in: locations)
        selectedLocation = CloudStorage.selected(in: locations)

        let s = SystemPrefsSync(storageRoot: CloudStorage.root(for: selectedLocation))
        sync = s
        storageReady = true
        storagePath = s.fileURL.path

        if let missing = CloudStorage.missingSelection(in: locations) {
            storageWarning = "\(missing.displayName) não foi encontrado neste Mac — gravando só localmente, não vai sincronizar. Escolha outro serviço ou instale o \(missing.displayName)."
        } else if selectedLocation == nil {
            storageWarning = "Nenhum serviço de nuvem (iCloud Drive, Google Drive, OneDrive) encontrado — gravando só localmente, não vai sincronizar entre Macs."
        } else {
            storageWarning = nil
        }
        refreshCloudInfo()
    }

    /// Troca o serviço de nuvem usado por este Mac.
    func select(locationID: String) {
        guard let loc = locations.first(where: { $0.id == locationID }),
              loc != selectedLocation else { return }
        CloudStorage.select(loc)
        configure()
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
        let captured = sync.capture(recipe)
        let total = captured.totalKeys
        do {
            let url = try sync.save(captured, hostName: hostName, date: Date())
            refreshCloudInfo()
            output = ActionOutput(
                title: "Configurações do Finder salvas",
                text: "\(total) configurações lidas deste Mac e salvas em \(destinationName).\n\nArquivo: \(url.path)\n\nAgora, no outro Mac, abra o iMackPeek e clique em “Aplicar”.",
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
                    ? "O arquivo de configurações do Finder foi removido de \(destinationName).\n\nSuas configurações locais do Finder NÃO foram alteradas — só apaguei a cópia salva. Você pode clicar em “Salvar” de novo quando quiser."
                    : "Não havia configurações salvas em \(destinationName).",
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
                text: "Não há configurações do Finder salvas em \(destinationName) ainda.\nSalve primeiro no outro Mac — usando o mesmo serviço de nuvem.\n\nProcurado em: \(sync.fileURL.path)",
                succeeded: false)
            return
        }

        // 1) grava todas as configs via CFPreferences
        let result = sync.apply(snap, recipe: recipe)

        // 2) força os daemons a relerem (cfprefsd = cache; Finder e
        //    WindowManager = quem desenha janelas e a Mesa)
        _ = try? await Shell.runAsync("/usr/bin/killall", ["cfprefsd"])
        for daemon in recipe.daemons {
            _ = try? await Shell.runAsync("/usr/bin/killall", [daemon])
        }
        try? await Task.sleep(nanoseconds: 800_000_000)

        // 3) aplica as barras vivas via AppleScript
        let desired = FinderUIApplier.desired(
            fromFinderDomain: snap.domains["com.apple.finder"],
            unsetKeys: snap.unset["com.apple.finder"] ?? [])
        let uiResult = await FinderUIApplier.apply(desired)

        var text = "\(result.applied) configurações aplicadas neste Mac (vindas de “\(snap.savedBy ?? "?")”)."
        if result.reset > 0 {
            text += "\n\(result.reset) configurações voltaram ao padrão do macOS, como estão na origem."
        }
        text += "\nFinder reiniciado."
        if snap.lacksUnsetKeys {
            text += "\n\nAviso: este arquivo foi salvo por uma versão antiga do iMackPeek, que não registra as configurações deixadas no padrão (ex.: arquivos ocultos desligados). Clique em “Salvar” de novo em “\(snap.savedBy ?? "outro Mac")” para que elas também sejam aplicadas aqui."
        }
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
