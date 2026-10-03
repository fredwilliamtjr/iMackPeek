import Foundation

/// Uma preferência identificada por domínio + chave. A maioria das configs do
/// Finder mora em `com.apple.finder`, mas algumas (ex.: "mostrar todas as
/// extensões") moram no domínio global `NSGlobalDomain`.
struct PrefKey: Hashable {
    let domain: String
    let key: String
    init(_ domain: String, _ key: String) { self.domain = domain; self.key = key }
}

/// Uma "receita" de sincronização: um conjunto de chaves portáveis + os daemons
/// a reiniciar para aplicar.
///
/// Só as chaves listadas viajam entre Macs. Tudo que é estado local da máquina
/// (histórico de pastas, caminhos `/Users/<eu>/...`, posições de ícones e
/// volumes, frames de janela, IDs de conta iCloud, flags de migração e caches)
/// fica **de fora de propósito** — é o lixo que faz o Mackup recusar o Finder.
struct SyncRecipe: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let summary: String
    let keys: [PrefKey]
    let daemons: [String]

    /// Domínios distintos tocados por esta receita.
    var domains: [String] { Array(Set(keys.map(\.domain))) }
}

/// Catálogo de receitas. Ponto único de extensão: o Fred pede uma config nova,
/// identificamos a chave do macOS que a controla, e ela entra aqui.
enum SystemPrefsCatalog {
    static let recipes: [SyncRecipe] = [finder]

    /// Todas as configurações portáveis do Finder (Ajustes do Finder + menu
    /// Visualizar + opções de visualização + barra lateral/etiquetas).
    static let finder = SyncRecipe(
        id: "finder",
        name: "Finder",
        icon: "macwindow",
        summary: "Todas as configurações do Finder: barras, visualização, Mesa, avisos, lateral e etiquetas.",
        keys: {
            let F = "com.apple.finder"
            let G = UserDefaults.globalDomain  // "NSGlobalDomain"
            var k: [PrefKey] = []
            // --- barras + visualização (também aplicadas ao vivo via AppleScript) ---
            for key in ["FXPreferredViewStyle", "ShowPathbar", "ShowStatusBar", "ShowSidebar",
                        // barra de abas do Finder (chave do AppKit window tabbing; o
                        // nome tem o typo "Shoud" mesmo, vem assim do macOS)
                        "NSWindowTabbingShoudShowTabBarKey-com.apple.finder.TBrowserWindow"] {
                k.append(PrefKey(F, key))
            }
            // --- personalização da barra de ferramentas do Finder (botões do topo) ---
            k.append(PrefKey(F, "NSToolbar Configuration Browser"))
            // --- Ajustes ▸ Geral: ícones na Mesa, nova janela, abas ---
            for key in ["ShowHardDrivesOnDesktop", "ShowExternalHardDrivesOnDesktop",
                        "ShowRemovableMediaOnDesktop", "ShowMountedServersOnDesktop",
                        "NewWindowTarget", "NewWindowTargetPath", "FinderSpawnTab"] {
                k.append(PrefKey(F, key))
            }
            // --- Ajustes ▸ Avançado: extensões, avisos, lixo, ordenação, busca ---
            for key in ["AppleShowAllFiles", "FXEnableExtensionChangeWarning",
                        "FXEnableRemoveFromICloudDriveWarning", "WarnOnEmptyTrash",
                        "FXRemoveOldTrashItems", "_FXSortFoldersFirst",
                        "_FXSortFoldersFirstOnDesktop", "FXDefaultSearchScope"] {
                k.append(PrefKey(F, key))
            }
            // --- opções de visualização (tamanho de ícone, grade, colunas, grupos) ---
            for key in ["DesktopViewSettings", "StandardViewSettings", "FK_StandardViewSettings",
                        "StandardViewOptions", "FK_StandardViewOptions2", "FK_DefaultIconViewSettings",
                        "FK_DefaultListViewSettings", "TrashViewSettings", "NetworkViewSettings",
                        "ICloudViewSettings", "PackageViewSettings", "FXArrangeGroupViewBy"] {
                k.append(PrefKey(F, key))
            }
            // --- barra lateral + etiquetas ---
            for key in ["FK_AppCentricShowSidebar", "SidebarWidth2", "FK_SidebarWidth2",
                        "SidebarDevicesSectionDisclosedState", "SidebarPlacesSectionDisclosedState",
                        "SidebarTagsSctionDisclosedState", "FavoriteTagNames", "ShowRecentTags",
                        "TagsColumnWidth"] {
                k.append(PrefKey(F, key))
            }
            // --- domínio global: "mostrar todas as extensões de arquivo" ---
            k.append(PrefKey(G, "AppleShowAllExtensions"))
            // --- pastas com mola (abrir pasta ao arrastar por cima) ---
            k.append(PrefKey(G, "com.apple.springing.enabled"))
            k.append(PrefKey(G, "com.apple.springing.delay"))
            // --- ocultar ícones da Mesa (macOS Sonoma+); domínio WindowManager ---
            k.append(PrefKey("com.apple.WindowManager", "StandardHideDesktopIcons"))
            // --- servidores salvos em "Conectar ao servidor" ---
            for key in ["CustomListItems", "recentservers"] {
                k.append(PrefKey("com.apple.NetworkBrowser", key))
            }
            return k
        }(),
        daemons: ["Finder", "WindowManager"]
    )

    static func recipe(id: String) -> SyncRecipe? { recipes.first { $0.id == id } }

    /// Descrição legível, por grupo, do que a aba Finder sincroniza — para o
    /// informativo "O que é sincronizado?". Mantenha em sincronia com `finder.keys`.
    static let finderInfoGroups: [SyncInfoGroup] = [
        SyncInfoGroup(title: "Barras e visualização", icon: "sidebar.left", items: [
            "Estilo de visualização padrão (lista, ícone, coluna, galeria)",
            "Barra de caminho, de status, lateral e de abas",
            "Barra de ferramentas (quais botões aparecem no topo)",
        ]),
        SyncInfoGroup(title: "Mesa (Desktop)", icon: "menubar.dock.rectangle", items: [
            "Mostrar na Mesa: discos internos, externos, mídia removível e servidores",
            "Ocultar todos os ícones da Mesa",
            "Manter pastas no topo na Mesa",
        ]),
        SyncInfoGroup(title: "Janelas e navegação", icon: "macwindow.on.rectangle", items: [
            "Pasta que abre em uma nova janela",
            "Abrir pastas em abas em vez de novas janelas",
            "Pastas com mola (abrir ao arrastar um item por cima) e seu atraso",
        ]),
        SyncInfoGroup(title: "Avançado", icon: "gearshape", items: [
            "Mostrar arquivos ocultos e todas as extensões",
            "Avisos: trocar extensão, remover do iCloud Drive, esvaziar o lixo",
            "Esvaziar o lixo após 30 dias",
            "Manter pastas no topo e escopo padrão da busca",
        ]),
        SyncInfoGroup(title: "Opções de visualização", icon: "square.grid.2x2", items: [
            "Tamanho dos ícones, espaçamento da grade, colunas da lista e agrupamento",
            "Aplicado a: Mesa, janelas padrão, Lixo, Rede, iCloud e pacotes",
        ]),
        SyncInfoGroup(title: "Barra lateral e etiquetas", icon: "tag", items: [
            "Largura da barra lateral e seções abertas/fechadas",
            "Etiquetas favoritas, etiquetas recentes e largura da coluna de etiquetas",
        ]),
        SyncInfoGroup(title: "Rede", icon: "network", items: [
            "Servidores salvos e recentes em “Conectar ao servidor”",
        ]),
    ]
}

/// Um grupo de itens legíveis para o informativo "O que é sincronizado?".
struct SyncInfoGroup: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [String]
}

/// Lê e grava as preferências curadas direto do macOS via `CFPreferences`.
///
/// `CFPreferences` preserva o tipo nativo de cada valor (bool, número, string,
/// array, **dicionário** — caso das opções de visualização) e evita a armadilha
/// do `cfprefsd`. O snapshot é serializado como um `.plist` único dentro da
/// pasta do serviço de nuvem escolhido (iCloud Drive, Google Drive ou
/// OneDrive — ver `CloudStorage`), então sincroniza junto.
///
/// ⚠️ Importante: gravar via `CFPreferences` + reiniciar o Finder aplica a
/// maioria das configs (Mesa, avisos, lateral, opções de visualização), mas
/// **não** muda a visualização da janela viva nem a barra de caminho — isso é
/// estado de janela restaurada e exige acionar o Finder por AppleScript. Ver
/// `FinderUIApplier`.
struct SystemPrefsSync {

    /// Versão do formato do `finder-settings.plist`.
    /// - 1: só as chaves com valor definido (`domains`).
    /// - 2: também lista as chaves sem valor na origem (`unset`), para que o
    ///   destino as apague e volte ao padrão do macOS.
    static let formatVersion = 2

    /// Raiz do serviço de nuvem (ex.: a pasta do iCloud Drive). O arquivo vai
    /// para `iMackPeek/finder-settings.plist` dentro dela.
    let storageRoot: URL

    var fileURL: URL {
        storageRoot
            .appendingPathComponent("iMackPeek", isDirectory: true)
            .appendingPathComponent("finder-settings.plist")
    }

    // MARK: - Captura (backup)

    /// Estado das chaves da receita neste Mac.
    struct Capture {
        /// `domínio → (chave → valor)` das chaves com valor definido.
        var domains: [String: [String: Any]] = [:]
        /// `domínio → [chave]` das chaves sem valor definido — ou seja, no
        /// padrão do macOS. Ex.: `AppleShowAllFiles` num Mac que nunca mostrou
        /// arquivos ocultos.
        var unset: [String: [String]] = [:]

        var totalKeys: Int {
            domains.values.reduce(0) { $0 + $1.count } + unset.values.reduce(0) { $0 + $1.count }
        }
    }

    /// Lê do sistema os valores atuais das chaves da receita. Chave sem valor
    /// também é registrada (em `unset`): sem isso, uma config ligada no destino
    /// e no padrão (desligada) na origem nunca seria desfeita no Aplicar.
    func capture(_ recipe: SyncRecipe) -> Capture {
        var result = Capture()
        for pk in recipe.keys {
            if let value = CFPreferencesCopyValue(
                pk.key as CFString, pk.domain as CFString,
                kCFPreferencesCurrentUser, kCFPreferencesAnyHost
            ) {
                result.domains[pk.domain, default: [:]][pk.key] = value
            } else {
                result.unset[pk.domain, default: []].append(pk.key)
            }
        }
        return result
    }

    @discardableResult
    func save(_ capture: Capture, hostName: String, date: Date) throws -> URL {
        let root: [String: Any] = [
            "version": Self.formatVersion,
            "savedAt": date,
            "savedBy": hostName,
            "domains": capture.domains,
            "unset": capture.unset,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Remove o snapshot salvo na nuvem (NÃO mexe nas configs locais do Mac).
    /// Retorna `true` se havia um arquivo e ele foi removido.
    @discardableResult
    func deleteSnapshot() throws -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        try FileManager.default.removeItem(at: fileURL)
        return true
    }

    // MARK: - Leitura / aplicação (restore)

    struct SavedSnapshot {
        let version: Int
        let savedAt: Date?
        let savedBy: String?
        let domains: [String: [String: Any]]
        /// Chaves sem valor na origem (formato 2+). Vazio em snapshots v1.
        let unset: [String: [String]]

        var totalKeys: Int {
            domains.values.reduce(0) { $0 + $1.count } + unset.values.reduce(0) { $0 + $1.count }
        }

        /// Snapshot antigo (v1), que não registra as chaves no padrão.
        var lacksUnsetKeys: Bool { version < 2 }
    }

    func load() throws -> SavedSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        guard let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any] else { return nil }
        return SavedSnapshot(
            version: (root["version"] as? Int) ?? 0,
            savedAt: root["savedAt"] as? Date,
            savedBy: root["savedBy"] as? String,
            domains: (root["domains"] as? [String: [String: Any]]) ?? [:],
            unset: (root["unset"] as? [String: [String]]) ?? [:]
        )
    }

    struct ApplyResult {
        /// Chaves gravadas com o valor da origem.
        let applied: Int
        /// Chaves apagadas neste Mac (voltaram ao padrão, como na origem).
        let reset: Int
    }

    /// Grava no sistema os valores do snapshot, restritos às chaves da receita,
    /// e apaga as chaves que estavam sem valor na origem — assim este Mac fica
    /// igual à origem também no que ela deixou no padrão. Chaves que o snapshot
    /// não menciona (ex.: receita ganhou chave depois do Salvar) não são tocadas.
    /// Não reinicia daemons nem aciona o Finder — quem chama consolida isso.
    @discardableResult
    func apply(_ snapshot: SavedSnapshot, recipe: SyncRecipe) -> ApplyResult {
        var applied = 0
        var reset = 0
        var touchedDomains = Set<String>()
        for pk in recipe.keys {
            if let value = snapshot.domains[pk.domain]?[pk.key] {
                CFPreferencesSetValue(
                    pk.key as CFString, value as CFPropertyList, pk.domain as CFString,
                    kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                touchedDomains.insert(pk.domain)
                applied += 1
            } else if snapshot.unset[pk.domain]?.contains(pk.key) == true,
                      CFPreferencesCopyValue(
                        pk.key as CFString, pk.domain as CFString,
                        kCFPreferencesCurrentUser, kCFPreferencesAnyHost) != nil {
                CFPreferencesSetValue(
                    pk.key as CFString, nil, pk.domain as CFString,
                    kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
                touchedDomains.insert(pk.domain)
                reset += 1
            }
        }
        for domain in touchedDomains {
            CFPreferencesAppSynchronize(domain as CFString)
        }
        return ApplyResult(applied: applied, reset: reset)
    }
}
