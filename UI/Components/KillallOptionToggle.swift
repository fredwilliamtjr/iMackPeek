import SwiftUI

/// Toggle para reiniciar Finder, Dock e cfprefsd após o restore (seção 5.4).
/// Ligado por padrão; avisa que janelas do Finder serão fechadas.
struct KillallOptionToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reiniciar Finder, Dock e cfprefsd após o restore")
                    Text("Necessário para o macOS reler algumas preferências. As janelas abertas do Finder serão fechadas.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }
}
