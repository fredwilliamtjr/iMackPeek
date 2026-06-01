import Foundation
import SwiftUI

/// Coordenador central do app, compartilhado entre a janela e a barra de menu.
///
/// O app é uma ferramenta de **abas** — uma por funcionalidade de
/// sincronização. A primeira é o Finder. Não há mais nada de Mackup.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let finderSync = FinderSyncViewModel()

    @Published var mode: AppMode = .finder

    private init() {}
}
