import SwiftUI

/// Tela exibida quando o `mackup` não é encontrado no sistema (seção 5.2).
///
/// Se o Homebrew estiver presente, oferece instalação assistida via
/// `brew install mackup`. Caso contrário, instrui o usuário a instalar o
/// Homebrew primeiro.
struct InstallMackupView: View {
    @EnvironmentObject private var environment: MackupEnvironment

    @State private var isInstalling = false
    @State private var installLog = ""
    @State private var installError: String?

    private var hasBrew: Bool { environment.brewPath != nil }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Mackup não encontrado")
                .font(.title.bold())

            Text("O iMackPeek precisa do utilitário **Mackup** instalado para funcionar. "
                 + "Ele é gratuito e de código aberto.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)

            if hasBrew {
                brewInstallSection
            } else {
                noBrewSection
            }

            if let installError {
                Text(installError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 460)
            }

            if !installLog.isEmpty {
                ScrollView {
                    Text(installLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: 460, maxHeight: 140)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            Button("Verificar novamente") {
                Task { await environment.refresh() }
            }
            .disabled(isInstalling)
        }
        .padding(32)
    }

    @ViewBuilder
    private var brewInstallSection: some View {
        VStack(spacing: 12) {
            if isInstalling {
                ProgressView("Instalando via Homebrew…")
            } else {
                Button {
                    Task { await installViaBrew() }
                } label: {
                    Label("Instalar via Homebrew", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: 240)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            Text("Executa `brew install mackup`")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private static let brewInstallCommand =
        #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#

    @ViewBuilder
    private var noBrewSection: some View {
        VStack(spacing: 12) {
            Text("O Homebrew também não foi encontrado — ele é necessário para instalar o Mackup.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                TerminalLauncher.run(Self.brewInstallCommand)
            } label: {
                Label("Instalar Homebrew no Terminal", systemImage: "terminal.fill")
                    .frame(maxWidth: 260)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Text("Abre o Terminal e roda o instalador oficial (pede sua senha). "
                 + "Ao terminar, volte aqui e clique em “Verificar novamente”.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Link("O que é o Homebrew? (brew.sh)", destination: URL(string: "https://brew.sh")!)
                .font(.caption)
        }
        .frame(maxWidth: 460)
    }

    private func installViaBrew() async {
        guard let brew = environment.brewPath else { return }
        isInstalling = true
        installError = nil
        installLog = ""
        defer { isInstalling = false }

        do {
            let result = try await Shell.runAsync(brew, ["install", "mackup"])
            installLog = [result.stdout, result.stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            if !result.succeeded {
                installError = "A instalação retornou erro (exit \(result.exitCode))."
            }
        } catch {
            installError = error.localizedDescription
        }

        // Reavalia o ambiente independentemente do resultado.
        await environment.refresh()
    }
}
