import SwiftUI

/// Modo "Finder": salva todas as configurações do Finder desta máquina na nuvem
/// e aplica na outra. Dois botões grandes — Salvar (origem) e Aplicar (destino).
struct FinderSyncView: View {
    @ObservedObject var model: FinderSyncViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if !model.storageReady {
                Label("Storage não configurado: \(model.storagePath)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            cloudStatus

            HStack(spacing: 14) {
                actionCard(
                    title: "Salvar configurações do Finder",
                    subtitle: "Lê todas as configs deste Mac (“\(model.hostName)”) e grava na nuvem.",
                    icon: "arrow.up.circle.fill", tint: .blue,
                    button: "Salvar deste Mac"
                ) { Task { await model.save() } }

                actionCard(
                    title: "Aplicar configurações do Finder",
                    subtitle: "Pega o que está na nuvem e aplica neste Mac (reinicia o Finder).",
                    icon: "arrow.down.circle.fill", tint: .green,
                    button: "Aplicar neste Mac"
                ) { Task { await model.apply() } }
            }

            Spacer()
            footnote
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { model.configure() }
        .sheet(item: $model.output) { ActionOutputView(output: $0) }
        .overlay {
            if model.isRunning {
                ProgressView().controlSize(.large)
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sincronizar Finder").font(.title2.bold())
            Text("Transporta todas as configurações do Finder entre seus Macs — barras, visualização, Mesa, avisos, lateral e etiquetas.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var cloudStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: model.cloudInfo == nil ? "icloud.slash" : "icloud.fill")
                .foregroundStyle(model.cloudInfo == nil ? Color.secondary : Color.blue)
            Text(model.cloudInfo ?? "Nenhuma configuração do Finder salva na nuvem ainda.")
                .font(.callout)
            Spacer()
            Button { model.refreshCloudInfo() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func actionCard(title: String, subtitle: String, icon: String, tint: Color,
                            button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(tint)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(button, action: action)
                .buttonStyle(.borderedProminent).tint(tint)
                .disabled(!model.storageReady || model.isRunning)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footnote: some View {
        Text("A visualização (lista/ícone) e a barra de caminho são aplicadas acionando o Finder — pode pedir permissão de Acessibilidade na primeira vez. Dados específicos da máquina (histórico de pastas, posições de ícones) nunca são transportados.")
            .font(.caption2).foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
