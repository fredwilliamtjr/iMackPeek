import Foundation

/// Informações da versão do app, lidas do bundle (vêm do `project.yml`:
/// `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION`).
enum AppInfo {
    /// Versão curta, ex.: "0.2.0".
    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Número de build, ex.: "3".
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// Ex.: "v0.2.0".
    static var version: String { "v\(shortVersion)" }

    /// Ex.: "v0.2.0 (3)".
    static var versionWithBuild: String { "v\(shortVersion) (\(build))" }
}
