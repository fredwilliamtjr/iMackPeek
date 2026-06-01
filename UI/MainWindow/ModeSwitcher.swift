import SwiftUI

/// Abas do app. Uma por funcionalidade de sincronização — cresce conforme
/// criamos novas. A primeira é o Finder.
enum AppMode: String, CaseIterable, Identifiable, Codable {
    case finder = "Finder"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .finder: return "macwindow"
        }
    }
}

/// Seletor de aba (segmented) exibido no topo da janela. Só aparece quando há
/// mais de uma aba.
struct ModeSwitcher: View {
    @Binding var mode: AppMode

    var body: some View {
        Picker("Aba", selection: $mode) {
            ForEach(AppMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

/// Raiz da janela: barra de topo com a aba ativa e o conteúdo dela.
struct ContentRootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if AppMode.allCases.count > 1 {
                    ModeSwitcher(mode: $app.mode)
                } else {
                    Label(app.mode.rawValue, systemImage: app.mode.systemImage)
                        .font(.headline)
                }
                Spacer()
                Text("iMackPeek \(AppInfo.version)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            switch app.mode {
            case .finder:
                FinderSyncView(model: app.finderSync)
            }
        }
    }
}
