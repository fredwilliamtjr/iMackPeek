import Foundation

/// Resolve e inspeciona a pasta de storage onde o Mackup guarda os backups.
///
/// O Mackup copia os arquivos preservando o caminho relativo ao home dentro de
/// uma subpasta (por padrão "Mackup") na raiz do engine escolhido. Para o
/// Restore, essa pasta funciona como "base" análoga ao home no Backup.
struct StorageInspector {
    let config: MackupConfig

    /// Nome da subpasta do Mackup dentro da raiz do engine. Vem da opção
    /// `[storage] directory` (default "Mackup"). NÃO confundir com `path`.
    private var folderName: String { config.storageDirectory ?? "Mackup" }

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Raiz do engine de storage (sem a subpasta do Mackup), conforme o engine.
    /// Os nomes batem com as constantes do mackup 0.10.3 (constants.py).
    /// Retorna `nil` para engines cuja raiz não conseguimos resolver.
    func engineRoot() -> URL? {
        switch config.effectiveEngine.lowercased() {
        case "icloud":
            return home
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        case "dropbox":
            return home.appendingPathComponent("Dropbox")
        case "google_drive":
            return home.appendingPathComponent("Google Drive")
        case "file_system":
            // Para file_system o mackup usa HOME/<path> como base (path é
            // obrigatório e relativo ao home, salvo caminho absoluto).
            guard let path = config.storagePath, !path.isEmpty else { return nil }
            return path.hasPrefix("/")
                ? URL(fileURLWithPath: path)
                : home.appendingPathComponent(path)
        default:
            return nil
        }
    }

    /// URL completa da pasta de backups do Mackup.
    func storageURL() -> URL? {
        engineRoot()?.appendingPathComponent(folderName)
    }

    /// `true` se a pasta de storage existe e tem ao menos um item.
    func hasBackups() -> Bool {
        guard let url = storageURL(),
              let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        else { return false }
        return !contents.isEmpty
    }
}
