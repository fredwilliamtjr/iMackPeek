import SwiftUI

/// Modos principais do app (seção 4 do briefing).
enum AppMode: String, CaseIterable, Identifiable, Codable {
    case backup = "Backup"
    case restore = "Restore"
    case profiles = "Perfis"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .backup: return "arrow.up.circle"
        case .restore: return "arrow.down.circle"
        case .profiles: return "person.crop.rectangle.stack"
        }
    }
}

/// Seletor de modo (segmented) exibido no topo da janela.
struct ModeSwitcher: View {
    @Binding var mode: AppMode

    var body: some View {
        Picker("Modo", selection: $mode) {
            ForEach(AppMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

/// Raiz da janela quando o ambiente está pronto: barra de topo com o seletor
/// de modo e o conteúdo do modo escolhido. Restore e Perfis chegam nas fases
/// seguintes (placeholder por enquanto).
struct ContentRootView: View {
    @EnvironmentObject private var environment: MackupEnvironment
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ModeSwitcher(mode: $app.mode)
                    .disabled(!environment.hasUserConfig)
                Spacer()
                Text("Mackup \(versionText) • \(storageLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if environment.hasUserConfig {
                switch app.mode {
                case .backup:
                    BackupModeView(model: app.backup)
                case .restore:
                    RestoreModeView(model: app.restore)
                case .profiles:
                    ProfilesView()
                }
            } else {
                // Primeira execução sem ~/.mackup.cfg: configura o storage antes
                // de liberar backup/restore (que dependem de um engine real).
                StorageSetupView()
            }
        }
    }

    private var storageLabel: String {
        environment.hasUserConfig ? environment.userConfig.effectiveEngine : "não configurado"
    }

    private var versionText: String {
        if case .ready(let version, _) = environment.status { return version }
        return "—"
    }
}

/// Placeholder para modos ainda não implementados.
struct ComingSoonView: View {
    let title: String
    let phase: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "hammer")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text("Em construção — \(phase).")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
