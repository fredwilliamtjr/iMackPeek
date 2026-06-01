import Foundation

/// Resultado de uma ação (salvar/aplicar), exibido em sheet pelo
/// `ActionOutputView`.
struct ActionOutput: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let succeeded: Bool
}
