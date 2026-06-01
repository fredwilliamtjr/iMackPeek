import SwiftUI

/// Janela principal: mostra a aba ativa. O app é uma ferramenta de abas de
/// sincronização (a primeira é o Finder) — sem mais nada de Mackup.
struct MainWindowView: View {
    var body: some View {
        ContentRootView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
