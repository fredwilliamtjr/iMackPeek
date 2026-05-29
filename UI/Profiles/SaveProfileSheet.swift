import SwiftUI

/// Sheet para nomear e salvar a seleção atual como um perfil.
struct SaveProfileSheet: View {
    @ObservedObject var store: ProfileStore
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var willOverwrite: Bool { !trimmed.isEmpty && store.exists(name: trimmed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Salvar perfil").font(.title3.bold())

            TextField("Nome do perfil", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            if willOverwrite {
                Label("Já existe um perfil com esse nome — será sobrescrito.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}
