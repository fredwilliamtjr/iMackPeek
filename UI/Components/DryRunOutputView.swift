import SwiftUI

/// Exibe a saída de uma ação do Mackup (preview dry-run ou backup real) em
/// fonte monoespaçada, dentro de um sheet.
struct DryRunOutputView: View {
    let output: ActionOutput
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(output.title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fechar") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                Text(output.text)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 620, height: 460)
    }

    private var subtitle: String {
        if output.isDryRun { return "Simulação — nenhum arquivo foi alterado." }
        return output.succeeded ? "Concluído com sucesso." : "Terminou com erros."
    }

    private var statusIcon: String {
        if output.isDryRun { return "eye" }
        return output.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill"
    }

    private var statusColor: Color {
        if output.isDryRun { return .accentColor }
        return output.succeeded ? .green : .red
    }
}
