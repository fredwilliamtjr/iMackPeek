import Foundation

/// Serviços de nuvem suportados como destino da sincronização.
enum CloudService: String, CaseIterable, Identifiable {
    case iCloud
    case googleDrive
    case oneDrive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iCloud: return "iCloud Drive"
        case .googleDrive: return "Google Drive"
        case .oneDrive: return "OneDrive"
        }
    }
}

/// Uma pasta de nuvem encontrada neste Mac (um serviço + conta).
struct CloudLocation: Identifiable, Hashable {
    let service: CloudService
    /// Conta, quando o serviço permite várias (ex.: e-mail do Google, empresa
    /// do OneDrive). `nil` quando não há o que distinguir.
    let account: String?
    let url: URL

    var id: String { url.path }

    var displayName: String {
        guard let account else { return service.displayName }
        return "\(service.displayName) (\(account))"
    }
}

/// Resolve a pasta de armazenamento do iMackPeek — onde os snapshots de
/// configuração são gravados e lidos para sincronizar entre Macs.
///
/// Usa a pasta local do serviço de nuvem escolhido (iCloud Drive, Google
/// Drive ou OneDrive) — quem leva o arquivo para o outro Mac é o próprio
/// cliente do serviço. A escolha é por Mac; os dois precisam usar o mesmo.
/// Se nenhum serviço estiver disponível, cai para Application Support (local
/// — o app não quebra, mas não sincroniza).
enum CloudStorage {

    private static let selectionKey = "cloudStorageSelection"

    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    private static var iCloudDrive: URL {
        home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    /// Pasta onde os clientes modernos (File Provider) montam Google Drive e
    /// OneDrive: `GoogleDrive-<email>` e `OneDrive-Personal`/`OneDrive-<Empresa>`.
    private static var cloudStorageDir: URL {
        home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
    }

    // MARK: - Descoberta

    /// Todas as pastas de nuvem encontradas neste Mac, na ordem de exibição.
    static func available() -> [CloudLocation] {
        let fm = FileManager.default
        var found: [CloudLocation] = []

        if isDirectory(iCloudDrive) {
            found.append(CloudLocation(service: .iCloud, account: nil, url: iCloudDrive))
        }

        let entries = ((try? fm.contentsOfDirectory(atPath: cloudStorageDir.path)) ?? []).sorted()

        // Google Drive: a raiz da conta só tem "Meu Drive"/"My Drive" e
        // atalhos — os arquivos do usuário ficam dentro de "Meu Drive".
        for name in entries where name.hasPrefix("GoogleDrive-") {
            let base = cloudStorageDir.appendingPathComponent(name, isDirectory: true)
            let account = String(name.dropFirst("GoogleDrive-".count))
            for drive in ["Meu Drive", "My Drive"] {
                let url = base.appendingPathComponent(drive, isDirectory: true)
                if isDirectory(url) {
                    found.append(CloudLocation(service: .googleDrive, account: account.isEmpty ? nil : account, url: url))
                    break
                }
            }
        }

        // OneDrive: a própria pasta é a raiz do drive.
        for name in entries where name.hasPrefix("OneDrive-") {
            let url = cloudStorageDir.appendingPathComponent(name, isDirectory: true)
            guard isDirectory(url) else { continue }
            let suffix = String(name.dropFirst("OneDrive-".count))
            let account = (suffix.isEmpty || suffix == "Personal") ? nil : suffix
            found.append(CloudLocation(service: .oneDrive, account: account, url: url))
        }
        // Cliente antigo do OneDrive (antes do File Provider): ~/OneDrive.
        let legacyOneDrive = home.appendingPathComponent("OneDrive", isDirectory: true)
        if !found.contains(where: { $0.service == .oneDrive }), isDirectory(legacyOneDrive) {
            found.append(CloudLocation(service: .oneDrive, account: nil, url: legacyOneDrive))
        }

        return found
    }

    /// Serviços sem nenhuma pasta encontrada neste Mac.
    static func missingServices(in locations: [CloudLocation]) -> [CloudService] {
        CloudService.allCases.filter { svc in !locations.contains { $0.service == svc } }
    }

    // MARK: - Escolha

    /// Pasta de nuvem em uso. Sem escolha salva, usa o iCloud Drive (padrão
    /// histórico) ou o primeiro serviço encontrado. Se a escolha salva sumiu
    /// (ex.: o cliente foi desinstalado), tenta outra conta do mesmo serviço;
    /// se não houver, devolve `nil` — **nunca troca de serviço sozinho**, para
    /// não gravar num lugar que o outro Mac não lê.
    static func selected(in locations: [CloudLocation]) -> CloudLocation? {
        guard let saved = savedSelection else {
            return locations.first { $0.service == .iCloud } ?? locations.first
        }
        if let exact = locations.first(where: { $0.id == saved.path }) { return exact }
        return locations.first { $0.service == saved.service }
    }

    /// Serviço escolhido pelo usuário que não foi encontrado neste Mac.
    static func missingSelection(in locations: [CloudLocation]) -> CloudService? {
        guard let saved = savedSelection, selected(in: locations) == nil else { return nil }
        return saved.service
    }

    static func select(_ location: CloudLocation) {
        UserDefaults.standard.set(
            ["service": location.service.rawValue, "path": location.url.path],
            forKey: selectionKey)
    }

    private static var savedSelection: (service: CloudService, path: String)? {
        guard let dict = UserDefaults.standard.dictionary(forKey: selectionKey),
              let raw = dict["service"] as? String, let service = CloudService(rawValue: raw),
              let path = dict["path"] as? String else { return nil }
        return (service, path)
    }

    // MARK: - Raiz

    /// Raiz de armazenamento. Os snapshots ficam em `iMackPeek/` dentro dela.
    static func root(for location: CloudLocation?) -> URL {
        if let location { return location.url }
        return (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true))
            ?? home.appendingPathComponent("Library/Application Support")
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
