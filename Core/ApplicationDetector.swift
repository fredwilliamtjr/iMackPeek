import Foundation

/// Descobre, para cada app suportado, quais caminhos de configuração existem
/// sob um diretório-base. Cruza `mackup show <app>` com checagens de
/// `FileManager`.
///
/// Os caminhos do `mackup show` são relativos ao home. O `baseDirectory`
/// permite reusar a mesma lógica para dois cenários:
///  - **Backup**: base = diretório home (o que existe neste Mac).
///  - **Restore**: base = pasta de storage (o que existe no backup).
struct ApplicationDetector {
    let cli: MackupCLI
    let baseDirectory: URL
    var sensitiveChecker: SensitivePathChecker?

    /// Inspeciona um único app. Retorna `nil` se o `mackup show` falhar
    /// (ex.: app que saiu da lista entre o `list` e o `show`).
    func inspect(slug: String) async -> DetectedApplication? {
        guard let show = try? await cli.show(slug) else { return nil }

        let paths = show.paths.map { relative -> ConfigPath in
            let absolute = baseDirectory.appendingPathComponent(relative).path
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: absolute, isDirectory: &isDir)
            let modDate = exists
                ? (try? FileManager.default.attributesOfItem(atPath: absolute)[.modificationDate]) as? Date
                : nil
            return ConfigPath(
                relativePath: relative,
                exists: exists,
                isDirectory: isDir.boolValue,
                modificationDate: modDate
            )
        }
        let sensitive = sensitiveChecker?.sensitiveMatches(in: show.paths) ?? []
        return DetectedApplication(slug: slug, name: show.name, paths: paths, sensitivePaths: sensitive)
    }

    /// Inspeciona todos os `slugs` com paralelismo limitado (seção 5.6).
    /// Chama `onProgress(concluídos, total)` na main thread a cada item.
    func scanAll(
        slugs: [String],
        maxConcurrent: Int = 10,
        onProgress: @MainActor @escaping (Int, Int) -> Void
    ) async -> [DetectedApplication] {
        let total = slugs.count
        var results: [DetectedApplication] = []
        results.reserveCapacity(total)
        var done = 0

        await withTaskGroup(of: DetectedApplication?.self) { group in
            var index = 0
            let initial = min(maxConcurrent, total)
            while index < initial {
                let slug = slugs[index]
                group.addTask { await inspect(slug: slug) }
                index += 1
            }

            while let result = await group.next() {
                done += 1
                let snapshot = done
                await MainActor.run { onProgress(snapshot, total) }
                if let result { results.append(result) }
                if index < total {
                    let slug = slugs[index]
                    group.addTask { await inspect(slug: slug) }
                    index += 1
                }
            }
        }
        return results
    }
}
