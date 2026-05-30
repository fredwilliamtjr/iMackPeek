import SwiftUI

/// Onboarding de storage (seção 5.1 do briefing): aparece na primeira execução,
/// quando ainda não existe `~/.mackup.cfg`. Sem um storage engine configurado,
/// o Mackup assume o default (Dropbox) e o backup/restore falham.
///
/// O usuário escolhe onde guardar os backups e o iMackPeek grava o
/// `~/.mackup.cfg` — a única situação em que o app escreve esse arquivo, e
/// sempre com esta confirmação explícita.
struct StorageSetupView: View {
    @EnvironmentObject private var environment: MackupEnvironment

    @State private var engine: MackupConfig.StorageEngine = .icloud
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Onde guardar seus backups?")
                .font(.title2.bold())

            Text("O Mackup ainda não está configurado nesta máquina. Escolha o destino "
                 + "dos backups e o iMackPeek cria o seu **~/.mackup.cfg**.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440)

            Picker("Destino", selection: $engine) {
                ForEach(MackupConfig.StorageEngine.allCases) { eng in
                    Label(eng.displayName, systemImage: eng.systemImage).tag(eng)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if engine.requiresExternalApp {
                Label("Requer o app \(engine.displayName) instalado e configurado nesta máquina.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 440)
            } else if engine == .fileSystem {
                Label("Os backups vão para a pasta ~/Mackup.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = environment.configError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 440)
            }

            if isCreating {
                ProgressView()
            } else {
                Button {
                    isCreating = true
                    Task {
                        await environment.createUserConfig(engine: engine)
                        isCreating = false
                    }
                } label: {
                    Label("Criar configuração", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: 240)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }

            Text("O iMackPeek nunca sobrescreve um ~/.mackup.cfg existente.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
