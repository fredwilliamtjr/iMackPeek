# MackPeek — Briefing Inicial

> App em desenvolvimento. Terceiro da família **Peek** (iCloudPeek, NetPeek).

## 1. O que é

MackPeek é um cliente macOS nativo que envelopa o **Mackup** (CLI de backup/restore de configurações de aplicativos, https://github.com/lra/mackup) com uma interface visual. O Mackup é poderoso mas é CLI-only desde 2013, e a issue pedindo GUI (#604) está aberta sem implementação. MackPeek preenche esse buraco.

Não é um fork nem uma reimplementação do Mackup. É um **wrapper visual** que:

1. Chama o `mackup` instalado via Homebrew
2. Lê a saída dos comandos `list` e `show <app>`
3. Detecta no sistema quais apps suportados têm arquivos presentes
4. Apresenta uma UI de seleção (checkbox por app)
5. Gera arquivos `.mackup.cfg` temporários conforme a seleção do usuário
6. Executa `mackup -c <config-temporário> backup` ou `restore`

## 2. Stack técnico

- **Linguagem**: Swift 5.9+
- **UI**: SwiftUI (janela principal) + AppKit (`NSStatusItem` opcional pra atalhos no menu bar)
- **Target mínimo**: macOS 13 (Ventura) — mesmo dos outros dois apps Peek
- **Bundle ID**: `com.smartfull.mackpeek`
- **Distribuição**: fora do Mac App Store (assinatura Developer ID + notarização)
- **Dependência externa**: Mackup instalado via Homebrew (`brew install mackup`). App detecta ausência e oferece instalação assistida.

## 3. Arquitetura — estrutura de pastas

```
MackPeek/
├── App/
│   ├── MackPeekApp.swift          # @main, configuração inicial
│   ├── AppDelegate.swift          # NSStatusItem, atalhos rápidos
│   └── Info.plist
├── Core/
│   ├── MackupCLI.swift            # wrapper de Process pra chamar `mackup`
│   ├── MackupParser.swift         # parser da saída de `list` e `show`
│   ├── ApplicationDetector.swift  # checa quais arquivos/pastas existem no sistema
│   ├── ConfigGenerator.swift      # gera .mackup.cfg temporário
│   ├── ProfileStore.swift         # persiste perfis nomeados em Application Support
│   └── StorageInspector.swift     # lê pasta do iCloud Drive (ou outro storage) pra modo restore
├── UI/
│   ├── MainWindow/
│   │   ├── MainWindowView.swift
│   │   ├── ModeSwitcher.swift     # Backup / Restore / Profiles
│   │   └── ActionBar.swift        # botões Pré-visualizar / Executar
│   ├── BackupMode/
│   │   ├── BackupModeView.swift
│   │   ├── ApplicationListView.swift
│   │   ├── ApplicationRow.swift   # checkbox + nome + arquivos detectados
│   │   └── FilePreviewSheet.swift # detalhe de arquivos por app
│   ├── RestoreMode/
│   │   ├── RestoreModeView.swift
│   │   └── AvailableItemsList.swift
│   ├── Profiles/
│   │   ├── ProfilesView.swift
│   │   └── SaveProfileSheet.swift
│   └── Components/
│       ├── SensitiveWarningBadge.swift
│       ├── DryRunOutputView.swift
│       └── KillallOptionToggle.swift
├── Utilities/
│   ├── Shell.swift                # abstração genérica de Process
│   ├── FileSystemHelpers.swift
│   ├── HomebrewDetector.swift     # localiza `mackup` em /usr/local/bin ou /opt/homebrew/bin
│   └── Logger.swift
└── Resources/
    ├── Assets.xcassets
    └── known-sensitive-paths.json # lista de paths sensíveis pra destacar com warning
```

## 4. Funcionalidades

### 4.1 Modo Backup

**Fluxo:**

1. Ao abrir, app dispara em background:
   - `mackup list` → recebe lista de ~500 apps suportados
   - Pra cada app: `mackup show <app>` → recebe paths que ele monitora
   - Pra cada path: testa `FileManager.default.fileExists(atPath:)`
2. UI mostra duas seções:
   - **Detectados no seu Mac** (expandido) — apps com pelo menos um arquivo presente, ordenados por relevância
   - **Suportados mas não detectados** (colapsado) — disponível pra marcar mesmo assim
3. Cada linha tem:
   - Checkbox
   - Nome do app
   - Contador de arquivos detectados (ex: "3 arquivos, 2 pastas")
   - Botão "Ver arquivos" → sheet com lista detalhada
   - Badge amarelo "⚠ Sensível" se algum path da lista está em `known-sensitive-paths.json` (`.ssh/`, `.aws/`, `.codex/auth.json`, `.kube/`, etc)
4. Barra superior:
   - Storage engine ativo (lê do `~/.mackup.cfg` real ou pergunta na primeira execução)
   - Total selecionado
   - Botão "Pré-visualizar" (gera config temporária + `mackup -c <tmp> -n backup`, mostra output)
   - Botão "Executar backup"

### 4.2 Modo Restore

**Fluxo:**

1. App lê a pasta de storage (`~/Library/Mobile Documents/com~apple~CloudDocs/Mackup/` por padrão, ou outra conforme `[storage]` do `.mackup.cfg`)
2. Lista todos os arquivos/pastas dentro dela
3. Cruza com `mackup list` + `mackup show <app>` pra agrupar itens soltos no app correspondente
4. UI similar à do Backup, com diferenças:
   - Mostra apenas o que está disponível no storage (não a lista completa de 500+)
   - Indica data de modificação do backup de cada item (`FileManager` → `attributesOfItem`)
   - Toggle no rodapé: "Reiniciar Finder, Dock e cfprefsd após restore" (default: ligado)
5. Pré-visualizar e Executar funcionam igual ao Backup, com `mackup -c <tmp> restore`

### 4.3 Perfis salvos

- Usuário pode salvar uma seleção como perfil nomeado ("Setup dev", "Sistema apenas", "Tudo")
- Perfis ficam em `~/Library/Application Support/MackPeek/profiles/<nome>.json`
- JSON contém: lista de apps selecionados, modo (backup/restore), opções (killall sim/não)
- UI tem dropdown "Carregar perfil" + botão "Salvar como perfil"
- Atalho no menu bar: "Backup com perfil X", "Restore com perfil X"

## 5. Detalhes técnicos importantes

### 5.1 Nunca tocar no `~/.mackup.cfg` do usuário

App **sempre** gera config temporária em `NSTemporaryDirectory() + "/mackpeek-<UUID>.cfg"` e usa `mackup -c <path>`. Isso preserva qualquer configuração manual que o usuário já tenha.

Exceção: na primeira execução, se não existir `~/.mackup.cfg`, oferecer criar um básico (só com `[storage] engine = icloud`). Com confirmação explícita.

### 5.2 Detecção do binário do Mackup

```swift
// Locais possíveis em ordem:
let candidates = [
    "/opt/homebrew/bin/mackup",      // Apple Silicon
    "/usr/local/bin/mackup",         // Intel
    "/usr/bin/mackup",                // pip global
]
```

Se nenhum existir, abrir tela "Instalar Mackup" com:
- Instruções pra instalar Homebrew (se ausente)
- Botão "Instalar via Homebrew" (executa `brew install mackup` em terminal embutido)

### 5.3 Paths sensíveis (warning amarelo)

`known-sensitive-paths.json` contém:

```json
[
  ".ssh/",
  ".aws/",
  ".gnupg/",
  ".codex/auth.json",
  ".kube/config",
  ".docker/config.json",
  ".netrc",
  "Library/Application Support/Code/User/secrets/",
  "Library/Keychains/"
]
```

App marca qualquer app cujo `mackup show` mencione algum desses paths. Tooltip explica o risco (credencial sendo enviada pra storage cloud).

### 5.4 Reiniciar daemons após restore

Após `mackup restore`, certas preferências do macOS só refletem depois de:

```bash
killall cfprefsd Finder Dock
```

Toggle ligado por padrão. Quando ativo, executa esse comando após restore. Importante: avisar que Finder e Dock vão reiniciar (janelas abertas no Finder fecham).

### 5.5 Parsing da saída do Mackup

`mackup list` retorna formato simples (uma linha por app). `mackup show <app>` tem formato estruturado tipo `.ini`:

```
Configuration files:
  - .gitconfig
  - .config/git/ignore
```

Parser deve ser tolerante a mudanças menores na saída (Mackup pode mudar formatação em versões futuras). Testes unitários cobrindo várias versões de saída.

### 5.6 Performance

`mackup show` chamado pra 500+ apps é lento se rodado serialmente (>30s). Usar:
- `TaskGroup` (Swift Concurrency) com paralelismo limitado (ex: 10 simultâneos)
- Cache local em `~/Library/Caches/MackPeek/show-cache.json` com TTL de 24h
- Loading state na UI durante o scan inicial

## 6. Fases de implementação

**Fase 1 — Fundação (semana 1)**
- Projeto Xcode inicializado, App SwiftUI básico
- `MackupCLI.swift` + `Shell.swift` rodando `mackup --version` e `mackup list`
- `HomebrewDetector.swift` localizando o binário
- Tela "Instalar Mackup" se ausente

**Fase 2 — Modo Backup MVP (semana 2)**
- `MackupParser.swift` parseando `list` e `show`
- `ApplicationDetector.swift` checando existência de paths
- Lista visual simples (sem warnings ainda)
- `ConfigGenerator.swift` gerando .cfg temporário
- Botões Pré-visualizar e Executar funcionando

**Fase 3 — Modo Restore MVP (semana 3)**
- `StorageInspector.swift` lendo pasta do iCloud
- UI de restore reaproveitando componentes do backup
- Toggle de killall pós-restore

**Fase 4 — Refinamentos (semana 4)**
- `SensitiveWarningBadge` integrado
- Sistema de perfis salvos
- Atalhos no menu bar
- Cache de `mackup show`

**Fase 5 — Polish e distribuição**
- Ícone do app
- Tela de boas-vindas
- Assinatura Developer ID + notarização Apple
- DMG de distribuição

## 7. Gotchas conhecidos

- **Mackup link mode está quebrado em Sonoma+** (PR #2085 introduziu copy mode). MackPeek deve **sempre** usar copy mode (default do `mackup backup`/`restore`). Nunca expor link mode na UI.
- **Versão do Mackup pelo Homebrew (0.10.3) pode divergir da doc do master no GitHub**. Confiar no `--help` da versão instalada, não na doc.
- **iCloud Drive pode estar com arquivos não-baixados** (placeholders). Antes de listar pra restore, pode ser necessário `brctl download <path>` pra garantir que tudo está local.
- **`mackup uninstall` standalone não existe na versão 0.10.3** — só `mackup link uninstall` (que só serve pra link mode). Pra "limpar" um backup em copy mode, deletar a pasta do storage manualmente. App deve oferecer botão "Limpar storage" com confirmação dupla.
- **Mackup escreve direto em paths protegidos do macOS** (`~/Library/Preferences/`). Em Sonoma+ algumas prefs podem requerer restart do daemon (cfprefsd) pra serem lidas após restore.
- **Apps escritos pra rodar como root** podem ter prefs em `/Library/Preferences/` (sem til) — esses o Mackup não pega e MackPeek também não precisa pegar.

## 8. Identidade visual

- Manter a estética dos apps Peek anteriores (iCloudPeek, NetPeek)
- Ícone: lupa estilizada sobre um arquivo de configuração, ou variação que sugira "espiar" e "configuração"
- Tema: respeitar light/dark mode do macOS
- Acentos: cor que diferencie dos outros dois (iCloudPeek usa azul-iCloud, NetPeek provavelmente verde-rede). Sugestão: laranja ou roxo pra MackPeek

## 9. Referências

- Mackup: https://github.com/lra/mackup
- Doc do Mackup: https://github.com/lra/mackup/blob/master/doc/README.md
- Issue do GUI (motivação): https://github.com/lra/mackup/issues/604
- iCloudPeek (app irmão): repositório local
- NetPeek (app irmão): repositório local

---

**Próximo passo no Claude Code:** Inicializar projeto Xcode com a estrutura de pastas da seção 3, criar `MackupCLI.swift` com chamada de teste a `mackup --version` e validar o pipeline básico de execução de comandos.
