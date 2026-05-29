import SwiftUI

/// Barra inferior do modo Backup: storage engine, total selecionado e os
/// botões Pré-visualizar / Executar.
struct ActionBar: View {
    @ObservedObject var model: BackupViewModel
    let storageEngine: String
    @State private var confirmingBackup = false

    var body: some View {
        HStack(spacing: 14) {
            Label(storageEngine, systemImage: "externaldrive.connected.to.line.below")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider().frame(height: 18)

            Text("\(model.selectedCount) selecionado\(model.selectedCount == 1 ? "" : "s")")
                .font(.callout)
                .foregroundStyle(model.selectedCount == 0 ? .secondary : .primary)

            Spacer()

            if model.isRunningAction {
                ProgressView().controlSize(.small)
            }

            Button {
                Task { await model.preview() }
            } label: {
                Label("Pré-visualizar", systemImage: "eye")
            }
            .disabled(!model.canRun)

            Button {
                confirmingBackup = true
            } label: {
                Label("Executar backup", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canRun)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .confirmationDialog(
            "Executar backup de \(model.selectedCount) app\(model.selectedCount == 1 ? "" : "s")?",
            isPresented: $confirmingBackup,
            titleVisibility: .visible
        ) {
            Button("Executar backup") { Task { await model.runBackup() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Os arquivos de configuração serão copiados para o storage \(storageEngine). "
                 + "Sua config pessoal (~/.mackup.cfg) não é alterada.")
        }
    }
}
