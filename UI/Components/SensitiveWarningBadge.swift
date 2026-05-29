import SwiftUI

/// Badge amarelo "⚠ Sensível" para apps que sincronizam credenciais/segredos
/// (seção 5.3). O tooltip lista os caminhos sensíveis e explica o risco.
struct SensitiveWarningBadge: View {
    let sensitivePaths: [String]

    var body: some View {
        Label("Sensível", systemImage: "exclamationmark.shield.fill")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.yellow.opacity(0.22), in: Capsule())
            .foregroundStyle(.orange)
            .help(tooltip)
    }

    private var tooltip: String {
        let list = sensitivePaths.map { "• \($0)" }.joined(separator: "\n")
        return "Este app inclui caminhos sensíveis que podem conter credenciais:\n\(list)\n\n"
             + "Ao fazer backup, esses arquivos serão copiados para o storage na nuvem."
    }
}
