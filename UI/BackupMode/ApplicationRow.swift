import SwiftUI

/// Uma linha da lista de apps: checkbox + nome + resumo de detecção +
/// botão "Ver arquivos". Badge de sensibilidade entra na Fase 4.
struct ApplicationRow: View {
    let app: DetectedApplication
    let isSelected: Bool
    let onToggle: () -> Void
    let onShowFiles: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.body)
                    if app.isSensitive {
                        SensitiveWarningBadge(sensitivePaths: app.sensitivePaths)
                    }
                }
                HStack(spacing: 6) {
                    Text(app.slug)
                        .foregroundStyle(.tertiary)
                    if app.isDetected {
                        Text("•").foregroundStyle(.tertiary)
                        Text(app.detectionSummary)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Button("Ver arquivos", action: onShowFiles)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
