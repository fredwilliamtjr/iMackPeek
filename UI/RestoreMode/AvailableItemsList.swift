import SwiftUI

/// Lista dos apps disponíveis no storage para restaurar. Cada linha mostra
/// checkbox, nome, resumo e a data do backup (modificação mais recente).
struct AvailableItemsList: View {
    @ObservedObject var model: RestoreViewModel
    @State private var previewApp: DetectedApplication?

    var body: some View {
        List {
            Section {
                ForEach(model.availableApps) { app in
                    row(for: app)
                }
            } header: {
                Text("Disponível no backup (\(model.availableApps.count))")
            }
        }
        .listStyle(.inset)
        .sheet(item: $previewApp) { app in
            FilePreviewSheet(app: app)
        }
    }

    private func row(for app: DetectedApplication) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { model.isSelected(app.slug) },
                set: { _ in model.toggle(app.slug) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name).font(.body)
                    if app.isSensitive {
                        SensitiveWarningBadge(sensitivePaths: app.sensitivePaths)
                    }
                }
                HStack(spacing: 6) {
                    Text(app.detectionSummary).foregroundStyle(.secondary)
                    if let date = app.latestModification {
                        Text("•").foregroundStyle(.tertiary)
                        Text(Self.dateFormatter.string(from: date)).foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Button("Ver arquivos") { previewApp = app }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(app.slug) }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
