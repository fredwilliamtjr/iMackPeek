import Foundation
import os

/// Logger central do app. Usa o subsystem do bundle id para que as mensagens
/// apareçam agrupadas no Console.app e em `log stream --predicate`.
enum Log {
    private static let subsystem = "com.smartfull.imackpeek"

    static let shell = Logger(subsystem: subsystem, category: "Shell")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let app = Logger(subsystem: subsystem, category: "App")
}
