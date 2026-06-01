import SwiftUI

/// Modo "Finder": salva todas as configurações do Finder desta máquina na nuvem
/// e aplica na outra. Dois botões grandes — Salvar (origem) e Aplicar (destino).
struct FinderSyncView: View {
    @ObservedObject var model: FinderSyncViewModel
    @State private var showingInfo = false
    @State private var confirmingDelete = false

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
        .sheet(isPresented: $showingInfo) { FinderSyncInfoView() }
        .overlay {
            if model.isRunning {
                ProgressView().controlSize(.large)
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sincronizar Finder").font(.title2.bold())
                Text("Transporta todas as configurações do Finder entre seus Macs — barras, visualização, Mesa, avisos, lateral e etiquetas.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button {
                showingInfo = true
            } label: {
                Label("O que é sincronizado?", systemImage: "info.circle")
            }
            .controlSize(.small)
            .fixedSize()
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
                .help("Atualizar")
            if model.cloudInfo != nil {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Excluir a sincronização salva na nuvem")
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "Excluir a sincronização salva na nuvem?",
            isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Excluir da nuvem", role: .destructive) { Task { await model.deleteSync() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Remove o arquivo de configurações do Finder do iCloud. Suas configurações locais do Finder NÃO são alteradas — e você pode salvar de novo quando quiser.")
        }
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

/// Folha informativa: lista, por grupo, tudo que a aba Finder sincroniza.
struct FinderSyncInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("O que é sincronizado", systemImage: "info.circle.fill")
                    .font(.headline)
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(SystemPrefsCatalog.finderInfoGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(group.title, systemImage: group.icon)
                                .font(.subheadline.bold())
                            ForEach(group.items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green).font(.caption)
                                        .padding(.top, 2)
                                    Text(item).font(.callout)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Não é transportado (de propósito)", systemImage: "xmark.circle")
                            .font(.subheadline.bold()).foregroundStyle(.secondary)
                        Text("Histórico de pastas, caminhos do tipo /Users/…, posições de ícones e volumes, posições de janelas, IDs de conta iCloud e flags de migração — porque bagunçariam a outra máquina.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Ainda não suportado: favoritos da barra lateral (o macOS recente mudou onde guarda isso).")
                            .font(.caption).foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
        }
        .frame(width: 560, height: 560)
    }
}
