import SwiftUI

/// Exibe o resultado de uma ação (salvar/aplicar) em fonte monoespaçada,
/// dentro de um sheet.
struct ActionOutputView: View {
    let output: ActionOutput
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: output.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(output.succeeded ? Color.green : Color.red)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(output.title).font(.headline)
                    Text(output.succeeded ? "Concluído com sucesso." : "Terminou com erros.")
                        .font(.caption).foregroundStyle(.secondary)
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
}
