import SwiftUI

/// Aba de perfis: lista os perfis salvos por modo, permite carregar (muda de
/// modo e aplica a seleção) ou excluir.
struct ProfilesView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            if app.profiles.profiles.isEmpty {
                emptyState
            } else {
                List {
                    section(title: "Backup", mode: .backup)
                    section(title: "Restore", mode: .restore)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func section(title: String, mode: AppMode) -> some View {
        let profiles = app.profiles.profiles(for: mode)
        if !profiles.isEmpty {
            Section(title) {
                ForEach(profiles) { profile in
                    HStack {
                        Image(systemName: mode.systemImage).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.name)
                            Text("\(profile.apps.count) app\(profile.apps.count == 1 ? "" : "s")"
                                 + (mode == .restore && profile.restartDaemons ? " • reinicia daemons" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Carregar") { app.loadProfile(profile) }
                            .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            app.profiles.delete(profile)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Nenhum perfil salvo").font(.title3.bold())
            Text("Monte uma seleção em Backup ou Restore e use “Salvar como perfil”.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }
}
