import SwiftUI

/// Tela do modo Backup: lista de apps + barra de ação. Faz o scan inicial
/// na primeira aparição usando o ambiente já validado.
struct BackupModeView: View {
    @EnvironmentObject private var environment: MackupEnvironment
    @EnvironmentObject private var app: AppModel
    @ObservedObject var model: BackupViewModel
    @State private var savingProfile = false

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            ActionBar(model: model, storageEngine: environment.userConfig.effectiveEngine)
        }
        .task {
            if let cli = environment.cli {
                await model.startIfNeeded(
                    cli: cli,
                    supportedApps: environment.supportedApps,
                    userConfig: environment.userConfig
                )
            }
        }
        .sheet(item: $model.actionOutput) { output in
            DryRunOutputView(output: output)
        }
        .sheet(isPresented: $savingProfile) {
            SaveProfileSheet(store: app.profiles) { name in
                if let profile = app.makeProfile(name: name) { app.profiles.save(profile) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.scanState {
        case .idle, .scanning:
            ScanProgressView(state: model.scanState)
        case .ready:
            VStack(spacing: 0) {
                selectionToolbar
                Divider()
                ApplicationListView(model: model)
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text("Falha no scan").font(.headline)
                Text(message).foregroundStyle(.secondary)
                Button("Tentar de novo") {
                    Task { await model.rescan(supportedApps: environment.supportedApps) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button("Selecionar detectados") { model.selectAllDetected() }
            Button("Limpar seleção") { model.deselectAll() }

            let backupProfiles = app.profiles.profiles(for: .backup)
            if !backupProfiles.isEmpty {
                Menu {
                    ForEach(backupProfiles) { profile in
                        Button(profile.name) { app.loadProfile(profile) }
                    }
                } label: {
                    Label("Carregar perfil", systemImage: "tray.and.arrow.down")
                }
                .fixedSize()
            }
            Button {
                savingProfile = true
            } label: {
                Label("Salvar como perfil", systemImage: "square.and.arrow.down")
            }
            .disabled(model.selectedCount == 0)

            Spacer()

            Button {
                Task { await model.rescan(supportedApps: environment.supportedApps) }
            } label: {
                Label("Atualizar", systemImage: "arrow.clockwise")
            }
        }
        .font(.callout)
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Estado de carregamento do scan, com contador de progresso.
private struct ScanProgressView: View {
    let state: BackupViewModel.ScanState

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: progressValue)
                .frame(width: 240)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressValue: Double? {
        if case .scanning(let done, let total) = state, total > 0 {
            return Double(done) / Double(total)
        }
        return nil
    }

    private var label: String {
        if case .scanning(let done, let total) = state {
            return "Analisando apps… \(done)/\(total)"
        }
        return "Preparando…"
    }
}
