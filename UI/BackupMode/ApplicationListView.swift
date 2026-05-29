import SwiftUI

/// Lista de apps em duas seções: detectados (expandida) e suportados mas não
/// detectados (recolhida). Um campo de busca no topo filtra ambas as seções.
/// A seleção é controlada pelo `BackupViewModel`.
struct ApplicationListView: View {
    @ObservedObject var model: BackupViewModel
    @State private var showOthers = false
    @State private var previewApp: DetectedApplication?

    /// Ao buscar, a seção de não-detectados abre automaticamente.
    private var othersExpanded: Bool {
        showOthers || !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $model.searchText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Divider()
            list
        }
    }

    private var list: some View {
        List {
            Section {
                if model.filteredDetected.isEmpty {
                    Text(emptyDetectedText)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(model.filteredDetected) { app in
                        row(for: app)
                    }
                }
            } header: {
                Text("Detectados no seu Mac (\(model.filteredDetected.count))")
            }

            Section {
                if othersExpanded {
                    ForEach(model.filteredOther) { app in
                        row(for: app)
                    }
                }
            } header: {
                Button {
                    withAnimation { showOthers.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: othersExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text("Suportados, mas não detectados (\(model.filteredOther.count))")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!model.searchText.isEmpty)
            }
        }
        .listStyle(.sidebar)
        .sheet(item: $previewApp) { app in
            FilePreviewSheet(app: app)
        }
    }

    private var emptyDetectedText: String {
        model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Nenhum app com configuração detectada neste Mac."
            : "Nenhum detectado corresponde à busca."
    }

    private func row(for app: DetectedApplication) -> some View {
        ApplicationRow(
            app: app,
            isSelected: model.isSelected(app.slug),
            onToggle: { model.toggle(app.slug) },
            onShowFiles: { previewApp = app }
        )
    }
}

/// Campo de busca reutilizável com ícone de lupa e botão de limpar.
struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar app por nome…", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }
}
