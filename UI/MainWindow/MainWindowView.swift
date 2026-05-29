import SwiftUI

/// Janela principal. Na Fase 1 ela roteia entre os estados do ambiente:
/// verificando, pronto (diagnóstico do pipeline), não instalado, ou falha.
/// Os modos Backup/Restore/Profiles entram nas fases seguintes.
struct MainWindowView: View {
    @EnvironmentObject private var environment: MackupEnvironment

    var body: some View {
        Group {
            switch environment.status {
            case .checking:
                CheckingView()
            case .ready:
                ContentRootView()
            case .notInstalled:
                InstallMackupView()
            case .failed(let message):
                FailureView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Estados

private struct CheckingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Verificando o Mackup…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FailureView: View {
    @EnvironmentObject private var environment: MackupEnvironment
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Não foi possível conversar com o Mackup")
                .font(.title3.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: 420)
            Button("Tentar de novo") {
                Task { await environment.refresh() }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(28)
    }
}
