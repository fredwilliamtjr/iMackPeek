import SwiftUI

/// Tela do modo Restore: lê o storage, lista o que dá pra restaurar, oferece
/// preview/restore e a opção de reiniciar daemons.
struct RestoreModeView: View {
    @EnvironmentObject private var environment: MackupEnvironment
    @EnvironmentObject private var app: AppModel
    @ObservedObject var model: RestoreViewModel
    @State private var confirmingRestore = false
    @State private var savingProfile = false

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            footer
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
        .sheet(item: $model.actionOutput) { DryRunOutputView(output: $0) }
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
            ScanProgress(state: model.scanState)
        case .empty:
            EmptyStorageView(path: model.storagePath) {
                Task { await model.rescan(supportedApps: environment.supportedApps) }
            }
        case .ready:
            VStack(spacing: 0) {
                toolbar
                Divider()
                AvailableItemsList(model: model)
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text("Falha ao ler o storage").font(.headline)
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Tentar de novo") {
                    Task { await model.rescan(supportedApps: environment.supportedApps) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("Selecionar tudo") { model.selectAll() }
            Button("Limpar seleção") { model.deselectAll() }

            let restoreProfiles = app.profiles.profiles(for: .restore)
            if !restoreProfiles.isEmpty {
                Menu {
                    ForEach(restoreProfiles) { profile in
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

    private var footer: some View {
        VStack(spacing: 10) {
            if model.scanState == .ready {
                KillallOptionToggle(isOn: $model.restartDaemons)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 14) {
                Label(environment.userConfig.effectiveEngine, systemImage: "externaldrive.connected.to.line.below")
                    .font(.callout).foregroundStyle(.secondary)
                Divider().frame(height: 18)
                Text("\(model.selectedCount) selecionado\(model.selectedCount == 1 ? "" : "s")")
                    .font(.callout)
                Spacer()
                if model.isRunningAction { ProgressView().controlSize(.small) }
                Button { Task { await model.preview() } } label: {
                    Label("Pré-visualizar", systemImage: "eye")
                }
                .disabled(!model.canRun)
                Button { confirmingRestore = true } label: {
                    Label("Restaurar", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .confirmationDialog(
            "Restaurar \(model.selectedCount) app\(model.selectedCount == 1 ? "" : "s")?",
            isPresented: $confirmingRestore,
            titleVisibility: .visible
        ) {
            Button("Restaurar", role: .destructive) { Task { await model.runRestore() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Os arquivos do storage vão sobrescrever as configurações locais correspondentes."
                 + (model.restartDaemons ? " Finder e Dock serão reiniciados ao final." : ""))
        }
    }
}

private struct EmptyStorageView: View {
    let path: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Nenhum backup encontrado").font(.title3.bold())
            Text("A pasta de storage está vazia ou ainda não existe:")
                .foregroundStyle(.secondary)
            Text(path)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
            Button("Verificar novamente", action: onRetry)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct ScanProgress: View {
    let state: RestoreViewModel.ScanState
    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress).frame(width: 240)
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var progress: Double? {
        if case .scanning(let d, let t) = state, t > 0 { return Double(d) / Double(t) }
        return nil
    }
    private var label: String {
        if case .scanning(let d, let t) = state { return "Lendo o backup… \(d)/\(t)" }
        return "Preparando…"
    }
}
