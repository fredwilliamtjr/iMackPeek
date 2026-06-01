import SwiftUI

@main
struct iMackPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppModel.shared

    var body: some Scene {
        // App de barra de menus puro: nenhuma janela é aberta no launch (início
        // silencioso). A janela principal é criada sob demanda pelo
        // WindowManager quando o usuário escolhe "Abrir iMackPeek".
        MenuBarExtra("iMackPeek", systemImage: "doc.text.magnifyingglass") {
            MenuBarContent()
                .environmentObject(app)
        }
    }
}
