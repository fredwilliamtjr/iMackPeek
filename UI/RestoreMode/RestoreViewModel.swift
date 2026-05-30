import Foundation
import SwiftUI

/// Estado do modo Restore: lê a pasta de storage, descobre o que está
/// disponível para restaurar, e executa preview/restore. Inclui a opção de
/// reiniciar daemons do macOS após o restore (seção 5.4).
@MainActor
final class RestoreViewModel: ObservableObject {

    enum ScanState: Equatable {
        case idle
        case scanning(done: Int, total: Int)
        case ready
        case empty               // storage não existe ou está vazio
        case failed(String)
    }

    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var availableApps: [DetectedApplication] = []
    @Published var selection: Set<String> = []
    @Published var restartDaemons = true     // killall cfprefsd Finder Dock
    @Published private(set) var isRunningAction = false
    @Published var actionOutput: ActionOutput?
    @Published private(set) var storagePath: String = ""

    private var cli: MackupCLI?
    private var config = MackupConfig()
    private let sensitiveChecker = SensitivePathChecker.loadFromBundle()

    var selectedCount: Int { selection.count }
    var canRun: Bool { selectedCount > 0 && !isRunningAction }

    // MARK: - Scan

    func startIfNeeded(cli: MackupCLI, supportedApps: [String], userConfig: MackupConfig) async {
        guard scanState == .idle else { return }
        self.cli = cli
        self.config = userConfig
        await scan(slugs: supportedApps)
    }

    func rescan(supportedApps: [String]) async {
        scanState = .idle
        await scan(slugs: supportedApps)
    }

    private func scan(slugs: [String]) async {
        guard let cli else {
            scanState = .failed("Mackup indisponível.")
            return
        }
        let inspector = StorageInspector(config: config)
        guard let storageURL = inspector.storageURL() else {
            scanState = .failed("Não foi possível localizar a pasta de storage do engine \(config.effectiveEngine).")
            return
        }
        storagePath = storageURL.path

        guard inspector.hasBackups() else {
            availableApps = []
            scanState = .empty
            return
        }

        scanState = .scanning(done: 0, total: slugs.count)
        let detector = ApplicationDetector(cli: cli, baseDirectory: storageURL, sensitiveChecker: sensitiveChecker)
        let all = await detector.scanAll(slugs: slugs) { [weak self] done, total in
            self?.scanState = .scanning(done: done, total: total)
        }
        await cli.flushShowCache()

        availableApps = all
            .filter(\.isDetected)
            .sorted {
                // Mais recentes primeiro; empate por nome.
                switch ($0.latestModification, $1.latestModification) {
                case let (l?, r?) where l != r: return l > r
                default: return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
        selection = Set(availableApps.map(\.slug))
        scanState = availableApps.isEmpty ? .empty : .ready
    }

    // MARK: - Seleção

    func isSelected(_ slug: String) -> Bool { selection.contains(slug) }
    func toggle(_ slug: String) {
        if selection.contains(slug) { selection.remove(slug) } else { selection.insert(slug) }
    }
    func selectAll() { selection = Set(availableApps.map(\.slug)) }
    func deselectAll() { selection.removeAll() }

    /// Substitui a seleção (usado ao carregar um perfil).
    func applySelection(_ slugs: Set<String>) { selection = slugs }

    // MARK: - Ações

    func preview() async { await runAction(title: "Pré-visualização do restore", dryRun: true) }
    func runRestore() async { await runAction(title: "Restore executado", dryRun: false) }

    private func runAction(title: String, dryRun: Bool) async {
        guard let cli, !selection.isEmpty else { return }
        isRunningAction = true
        defer { isRunningAction = false }

        do {
            let configURL = try ConfigGenerator.writeTemporaryConfig(
                selectedApps: Array(selection),
                basedOn: config
            )
            defer { try? FileManager.default.removeItem(at: configURL) }

            let result = try await cli.restore(configPath: configURL, dryRun: dryRun)
            var text = [result.stdout, result.stderr]
                .map { $0.strippingANSI().trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            // Reinício de daemons só no restore real bem-sucedido.
            if !dryRun, result.succeeded, restartDaemons {
                let killall = await restartSystemDaemons()
                text += "\n\n— \(killall)"
            }

            actionOutput = ActionOutput(
                title: title,
                text: text.isEmpty ? "(sem saída)" : text,
                succeeded: result.succeeded,
                isDryRun: dryRun
            )
        } catch {
            actionOutput = ActionOutput(title: title, text: error.localizedDescription, succeeded: false, isDryRun: dryRun)
        }
    }

    /// Executa `killall cfprefsd Finder Dock`. Retorna uma linha de status.
    private func restartSystemDaemons() async -> String {
        do {
            _ = try await Shell.runAsync("/usr/bin/killall", ["cfprefsd", "Finder", "Dock"])
            return "Finder, Dock e cfprefsd reiniciados."
        } catch {
            return "Não foi possível reiniciar os daemons: \(error.localizedDescription)"
        }
    }
}
