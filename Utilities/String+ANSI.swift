import Foundation

extension String {
    /// Remove sequências de escape ANSI (cores, negrito etc.) que o `mackup` e
    /// outras CLIs emitem na saída. Sem isso, códigos como `\u{1B}[91m` (vermelho)
    /// e `\u{1B}[0m` (reset) vazam crus na UI — aparecem como `[91m…[0m`.
    ///
    /// Cobre as sequências CSI padrão: `ESC [` seguido de bytes de parâmetro,
    /// bytes intermediários e um byte final.
    func strippingANSI() -> String {
        let pattern = "\u{1B}\\[[0-?]*[ -/]*[@-~]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
    }
}
