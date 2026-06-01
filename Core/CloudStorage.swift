import Foundation

/// Resolve a pasta de armazenamento do iMackPeek — onde os snapshots de
/// configuração são gravados e lidos para sincronizar entre Macs.
///
/// Usa diretamente o **iCloud Drive** (acessível a qualquer app, sem
/// entitlement especial). Se o iCloud Drive não estiver disponível, cai para
/// Application Support (local — o app não quebra, mas não sincroniza).
/// Sem nenhuma dependência do Mackup.
enum CloudStorage {

    private static var iCloudDrive: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    /// `true` se o destino é o iCloud Drive (ou seja, sincroniza entre Macs).
    static var isICloudAvailable: Bool {
        FileManager.default.fileExists(atPath: iCloudDrive.path)
    }

    /// Raiz de armazenamento. Os snapshots ficam em `iMackPeek/` dentro dela.
    static func root() -> URL {
        if isICloudAvailable { return iCloudDrive }
        return (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true))
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")
    }
}
