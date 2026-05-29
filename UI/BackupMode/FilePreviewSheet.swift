import SwiftUI

/// Sheet com a lista detalhada de caminhos de um app, indicando quais existem
/// neste Mac e quais não. Aberto pelo botão "Ver arquivos" da linha.
struct FilePreviewSheet: View {
    let app: DetectedApplication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.title3.bold())
                    Text(app.slug).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fechar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            List(app.paths) { path in
                HStack(spacing: 10) {
                    Image(systemName: icon(for: path))
                        .foregroundStyle(path.exists ? Color.accentColor : Color.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(path.displayName)
                            .font(.system(.body, design: .monospaced))
                        Text(path.relativePath)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(path.exists ? "presente" : "ausente")
                        .font(.caption)
                        .foregroundStyle(path.exists ? .green : .secondary)
                }
                .padding(.vertical, 2)
                .opacity(path.exists ? 1 : 0.55)
            }
            .listStyle(.inset)
        }
        .frame(width: 540, height: 420)
    }

    private func icon(for path: ConfigPath) -> String {
        if !path.exists { return "questionmark.circle" }
        return path.isDirectory ? "folder.fill" : "doc.fill"
    }
}
