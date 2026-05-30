import Foundation

/// Representação leve do `.mackup.cfg` (formato INI).
///
/// O iMackPeek **lê** o `~/.mackup.cfg` do usuário apenas para descobrir o
/// storage engine e o modo configurados — nunca o modifica (seção 5.1). Toda
/// escrita acontece em arquivos temporários gerados pelo `ConfigGenerator`.
struct MackupConfig: Equatable {
    /// Engine de storage: "icloud", "dropbox", "google_drive", "box", "file".
    var storageEngine: String?
    /// Diretório (usado quando engine = "file") — chave `directory`.
    var storageDirectory: String?
    /// Caminho relativo dentro do storage — chave `path`.
    var storagePath: String?
    /// Modo: "copy" ou "link". iMackPeek sempre força "copy" ao gerar config.
    var mode: String?

    /// Engine efetivo para exibição/uso, com fallback para iCloud.
    var effectiveEngine: String { storageEngine ?? "icloud" }

    static let userConfigURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".mackup.cfg")

    /// Lê e faz parse do `~/.mackup.cfg`, se existir. Somente leitura.
    static func loadUserConfig() -> MackupConfig? {
        guard let text = try? String(contentsOf: userConfigURL, encoding: .utf8) else {
            return nil
        }
        return parse(text)
    }

    /// `true` se o `~/.mackup.cfg` do usuário já existe.
    static var userConfigExists: Bool {
        FileManager.default.fileExists(atPath: userConfigURL.path)
    }

    enum WriteError: Error, LocalizedError {
        case alreadyExists
        var errorDescription: String? {
            switch self {
            case .alreadyExists:
                return "Já existe um ~/.mackup.cfg — o iMackPeek não sobrescreve a config do usuário."
            }
        }
    }

    /// Cria o `~/.mackup.cfg` do usuário na **primeira execução** (seção 5.1 do
    /// briefing) — única situação em que o iMackPeek escreve esse arquivo, e só
    /// após confirmação explícita na UI.
    ///
    /// Recusa-se a sobrescrever um arquivo existente. Para `file_system`, grava
    /// `path = <localFolderName>` (relativo ao HOME) e cria a pasta.
    static func writeUserConfig(engine: StorageEngine, localFolderName: String? = nil) throws {
        guard !userConfigExists else { throw WriteError.alreadyExists }

        var lines = ["# Criado pelo iMackPeek.", "", "[storage]", "engine = \(engine.rawValue)"]
        if engine == .fileSystem {
            let folder = (localFolderName?.isEmpty == false ? localFolderName! : "Mackup")
            lines.append("path = \(folder)")
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(folder)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        lines.append(contentsOf: ["", "[mode]", "mode = copy", ""])

        try lines.joined(separator: "\n").write(to: userConfigURL, atomically: true, encoding: .utf8)
    }

    /// Engines de storage suportados pelo Mackup que o iMackPeek oferece no
    /// onboarding. Os `rawValue` batem exatamente com o que o Mackup espera.
    enum StorageEngine: String, CaseIterable, Identifiable {
        case icloud
        case dropbox
        case googleDrive = "google_drive"
        case fileSystem = "file_system"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .icloud: return "iCloud Drive"
            case .dropbox: return "Dropbox"
            case .googleDrive: return "Google Drive"
            case .fileSystem: return "Pasta local"
            }
        }

        var systemImage: String {
            switch self {
            case .icloud: return "icloud"
            case .dropbox: return "shippingbox"
            case .googleDrive: return "externaldrive.badge.icloud"
            case .fileSystem: return "folder"
            }
        }

        /// Exige um app/serviço externo instalado pra funcionar.
        var requiresExternalApp: Bool {
            self == .dropbox || self == .googleDrive
        }
    }

    /// Parser tolerante de INI: reconhece `[secao]` e `chave = valor`,
    /// ignora comentários (`#`, `;`) e espaços.
    static func parse(_ text: String) -> MackupConfig {
        var config = MackupConfig()
        var section = ""

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = line.dropFirst().dropLast().lowercased()
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)

            switch (section, key) {
            case ("storage", "engine"): config.storageEngine = value
            case ("storage", "directory"): config.storageDirectory = value
            case ("storage", "path"): config.storagePath = value
            case ("mode", "mode"): config.mode = value
            default: break
            }
        }
        return config
    }
}
