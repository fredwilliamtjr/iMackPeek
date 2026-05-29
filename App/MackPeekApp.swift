import SwiftUI

@main
struct iMackPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppModel.shared

    var body: some Scene {
        WindowGroup(id: iMackPeekApp.mainWindowID) {
            MainWindowView()
                .environmentObject(app)
                .environmentObject(app.environment)
                .frame(minWidth: 760, minHeight: 520)
                .task { await app.bootstrap() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}  // sem "New Window"
        }

        // Ícone na barra de menus do macOS (estilo iCloudPeek / NetPeek):
        // mesmo glyph do ícone do app, renderizado como template (monocromático),
        // como manda a convenção da menu bar.
        MenuBarExtra("iMackPeek", systemImage: "doc.text.magnifyingglass") {
            MenuBarContent()
                .environmentObject(app)
        }
    }

    static let mainWindowID = "imackpeek-main"
}
