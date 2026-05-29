import Foundation

/// Resultado de uma ação do Mackup (preview dry-run, backup ou restore real),
/// exibido em sheet pelo `DryRunOutputView`. Compartilhado entre os modos.
struct ActionOutput: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let succeeded: Bool
    let isDryRun: Bool
}
