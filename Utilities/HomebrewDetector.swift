import Foundation

/// Localiza os binários `mackup` e `brew` no sistema.
///
/// A ordem dos candidatos segue a seção 5.2 do briefing: Apple Silicon
/// (`/opt/homebrew`) primeiro, depois Intel (`/usr/local`) e por fim uma
/// instalação global via pip (`/usr/bin`).
enum HomebrewDetector {

    static let mackupCandidates = [
        "/opt/homebrew/bin/mackup",  // Apple Silicon (Homebrew)
        "/usr/local/bin/mackup",     // Intel (Homebrew)
        "/usr/bin/mackup",           // pip global
    ]

    static let brewCandidates = [
        "/opt/homebrew/bin/brew",    // Apple Silicon
        "/usr/local/bin/brew",       // Intel
    ]

    /// Caminho do primeiro `mackup` executável encontrado, ou `nil`.
    static func locateMackup() -> String? {
        firstExecutable(in: mackupCandidates)
    }

    /// Caminho do primeiro `brew` executável encontrado, ou `nil`.
    static func locateBrew() -> String? {
        firstExecutable(in: brewCandidates)
    }

    private static func firstExecutable(in candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
