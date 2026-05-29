import Foundation

/// Um caminho de configuração monitorado pelo Mackup para um app.
/// `relativePath` é relativo ao diretório home do usuário (ex.: ".gitconfig",
/// "Library/Application Support/Code/User/settings.json").
struct ConfigPath: Identifiable, Hashable {
    let relativePath: String
    let exists: Bool
    let isDirectory: Bool
    /// Data de modificação do item (quando existe), usada no modo Restore.
    let modificationDate: Date?

    init(relativePath: String, exists: Bool, isDirectory: Bool, modificationDate: Date? = nil) {
        self.relativePath = relativePath
        self.exists = exists
        self.isDirectory = isDirectory
        self.modificationDate = modificationDate
    }

    var id: String { relativePath }

    /// Último componente do caminho, para exibição compacta.
    var displayName: String {
        (relativePath as NSString).lastPathComponent
    }
}

/// Um app suportado pelo Mackup, já cruzado com o que existe neste Mac.
struct DetectedApplication: Identifiable, Hashable {
    let slug: String            // identificador do mackup, ex.: "git"
    let name: String            // nome legível, ex.: "Git"
    let paths: [ConfigPath]
    /// Caminhos do app que casam com a lista de paths sensíveis (seção 5.3).
    let sensitivePaths: [String]

    init(slug: String, name: String, paths: [ConfigPath], sensitivePaths: [String] = []) {
        self.slug = slug
        self.name = name
        self.paths = paths
        self.sensitivePaths = sensitivePaths
    }

    var id: String { slug }

    /// `true` se o app monitora ao menos um caminho sensível.
    var isSensitive: Bool { !sensitivePaths.isEmpty }

    /// Caminhos que de fato existem neste Mac.
    var presentPaths: [ConfigPath] { paths.filter(\.exists) }

    /// O app é considerado "detectado" se tem ao menos um caminho presente.
    var isDetected: Bool { !presentPaths.isEmpty }

    var presentFileCount: Int { presentPaths.filter { !$0.isDirectory }.count }
    var presentFolderCount: Int { presentPaths.filter(\.isDirectory).count }

    /// Data de modificação mais recente entre os caminhos presentes.
    var latestModification: Date? {
        presentPaths.compactMap(\.modificationDate).max()
    }

    /// Resumo tipo "3 arquivos, 2 pastas" (omite o que for zero).
    var detectionSummary: String {
        var parts: [String] = []
        let files = presentFileCount
        let folders = presentFolderCount
        if files > 0 { parts.append("\(files) arquivo\(files == 1 ? "" : "s")") }
        if folders > 0 { parts.append("\(folders) pasta\(folders == 1 ? "" : "s")") }
        return parts.isEmpty ? "nenhum arquivo presente" : parts.joined(separator: ", ")
    }
}
