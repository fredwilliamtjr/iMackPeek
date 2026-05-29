import Foundation
import SwiftUI

/// Um perfil salvo: uma seleção nomeada de apps para um modo (seção 4.3).
struct Profile: Identifiable, Codable, Hashable {
    let name: String
    let mode: AppMode
    let apps: [String]
    let restartDaemons: Bool

    var id: String { name }
}

/// Persiste perfis em `~/Library/Application Support/iMackPeek/profiles/<nome>.json`.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []

    private let directory: URL

    init() {
        directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("iMackPeek/profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
    }

    /// Perfis de um modo específico, ordenados por nome.
    func profiles(for mode: AppMode) -> [Profile] {
        profiles.filter { $0.mode == mode }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// (Re)carrega os perfis do disco.
    func reload() {
        let decoder = JSONDecoder()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        profiles = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Profile.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Salva (ou sobrescreve) um perfil.
    func save(_ profile: Profile) {
        let url = fileURL(for: profile.name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(profile) {
            try? data.write(to: url, options: .atomic)
        }
        reload()
    }

    /// Remove um perfil.
    func delete(_ profile: Profile) {
        try? FileManager.default.removeItem(at: fileURL(for: profile.name))
        reload()
    }

    /// `true` se já existe um perfil com esse nome.
    func exists(name: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: name).path)
    }

    private func fileURL(for name: String) -> URL {
        // Sanitiza o nome para um filename seguro.
        let safe = name
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return directory.appendingPathComponent("\(safe.isEmpty ? "perfil" : safe).json")
    }
}
