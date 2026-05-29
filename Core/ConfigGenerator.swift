import Foundation

/// Gera arquivos `.mackup.cfg` temporários conforme a seleção do usuário.
///
/// Princípios (seções 5.1 e 7 do briefing):
///  - **Nunca** escreve no `~/.mackup.cfg` do usuário.
///  - **Sempre** força `mode = copy` (link mode está quebrado no Sonoma+).
///  - Restringe o sync aos apps marcados via `[applications_to_sync]`
///    (whitelist do Mackup): se presente, o Mackup sincroniza só esses.
enum ConfigGenerator {

    /// Monta o texto do arquivo de config a partir de uma base e da seleção.
    static func makeConfigText(selectedApps: [String], basedOn base: MackupConfig) -> String {
        var lines: [String] = []

        lines.append("# Gerado automaticamente pelo iMackPeek — não editar.")
        lines.append("")
        lines.append("[storage]")
        lines.append("engine = \(base.effectiveEngine)")
        if let directory = base.storageDirectory, !directory.isEmpty {
            lines.append("directory = \(directory)")
        }
        if let path = base.storagePath, !path.isEmpty {
            lines.append("path = \(path)")
        }
        lines.append("")
        lines.append("[mode]")
        lines.append("mode = copy")  // sempre copy — link mode nunca é usado
        lines.append("")
        lines.append("[applications_to_sync]")
        for slug in selectedApps.sorted() {
            lines.append(slug)
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Escreve a config temporária e devolve a URL. O chamador é responsável
    /// por removê-la depois do uso.
    ///
    /// IMPORTANTE: o Mackup 0.10.3 **recusa** um `-c <arquivo>` que não esteja
    /// dentro do diretório home ("config file is not in your home directory").
    /// Por isso o arquivo é gravado em `~/.imackpeek-<UUID>.cfg` — oculto,
    /// efêmero e **distinto** do `~/.mackup.cfg` do usuário, que nunca tocamos.
    static func writeTemporaryConfig(selectedApps: [String], basedOn base: MackupConfig) throws -> URL {
        let text = makeConfigText(selectedApps: selectedApps, basedOn: base)
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".imackpeek-\(UUID().uuidString).cfg")
        try text.write(to: url, atomically: true, encoding: .utf8)
        Log.cli.debug("config temporária: \(url.path, privacy: .public)")
        return url
    }
}
