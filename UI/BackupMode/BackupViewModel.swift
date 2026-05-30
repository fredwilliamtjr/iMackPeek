import Foundation
import SwiftUI

/// Estado do modo Backup: scan dos apps, seleção, pré-visualização (dry-run)
/// e execução real do backup.
@MainActor
final class BackupViewModel: ObservableObject {

    enum ScanState: Equatable {
        case idle
        case scanning(done: Int, total: Int)
        case ready
        case failed(String)
    }

    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var detectedApps: [DetectedApplication] = []
    @Published private(set) var otherApps: [DetectedApplication] = []
    @Published var selection: Set<String> = []
    @Published var searchText = ""
    @Published private(set) var isRunningAction = false
    @Published var actionOutput: ActionOutput?

    private var cli: MackupCLI?
    private var config = MackupConfig()
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let sensitiveChecker = SensitivePathChecker.loadFromBundle()

    var selectedCount: Int { selection.count }
    var canRun: Bool { selectedCount > 0 && !isRunningAction }

    /// Detectados filtrados pela busca (nome ou slug).
    var filteredDetected: [DetectedApplication] { filtered(detectedApps) }
    /// Não-detectados filtrados pela busca.
    var filteredOther: [DetectedApplication] { filtered(otherApps) }

    private func filtered(_ apps: [DetectedApplication]) -> [DetectedApplication] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.slug.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Scan

    /// Dispara o scan uma única vez (idempotente enquanto não falha).
    func startIfNeeded(cli: MackupCLI, supportedApps: [String], userConfig: MackupConfig) async {
        guard scanState == .idle else { return }
        self.cli = cli
        self.config = userConfig
        await scan(slugs: supportedApps)
    }

    /// Reexecuta o scan (botão "Atualizar").
    func rescan(supportedApps: [String]) async {
        scanState = .idle
        await scan(slugs: supportedApps)
    }

    private func scan(slugs: [String]) async {
        guard let cli else {
            scanState = .failed("Mackup indisponível.")
            return
        }
        scanState = .scanning(done: 0, total: slugs.count)
        let detector = ApplicationDetector(cli: cli, baseDirectory: home, sensitiveChecker: sensitiveChecker)
        let all = await detector.scanAll(slugs: slugs) { [weak self] done, total in
            self?.scanState = .scanning(done: done, total: total)
        }
        await cli.flushShowCache()

        detectedApps = all
            .filter(\.isDetected)
            .sorted {
                if $0.presentPaths.count != $1.presentPaths.count {
                    return $0.presentPaths.count > $1.presentPaths.count
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        otherApps = all
            .filter { !$0.isDetected }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Pré-seleciona todos os detectados — escolha mais comum no backup.
        selection = Set(detectedApps.map(\.slug))
        scanState = .ready
    }

    // MARK: - Seleção

    func isSelected(_ slug: String) -> Bool { selection.contains(slug) }

    func toggle(_ slug: String) {
        if selection.contains(slug) { selection.remove(slug) } else { selection.insert(slug) }
    }

    func selectAllDetected() { selection.formUnion(detectedApps.map(\.slug)) }
    func deselectAll() { selection.removeAll() }

    /// Substitui a seleção (usado ao carregar um perfil).
    func applySelection(_ slugs: Set<String>) { selection = slugs }

    // MARK: - Ações

    /// Pré-visualização: gera config temporária e roda `backup -n` (dry-run).
    func preview() async {
        await runAction(title: "Pré-visualização do backup", dryRun: true)
    }

    /// Execução real do backup. A confirmação acontece na UI antes daqui.
    func runBackup() async {
        await runAction(title: "Backup executado", dryRun: false)
    }

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

            let result = try await cli.backup(configPath: configURL, dryRun: dryRun)
            let text = [result.stdout, result.stderr]
                .map { $0.strippingANSI().trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            actionOutput = ActionOutput(
                title: title,
                text: text.isEmpty ? "(sem saída)" : text,
                succeeded: result.succeeded,
                isDryRun: dryRun
            )
        } catch {
            actionOutput = ActionOutput(
                title: title,
                text: error.localizedDescription,
                succeeded: false,
                isDryRun: dryRun
            )
        }
    }
}
