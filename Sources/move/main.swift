import AppKit
import MoveCore

let usage = """
    usage: move [run] [--config <path>]
           move check [--config <path>]

    run     Register the shortcuts and move windows (the default).
    check   Validate the config and exit.

    The default config is \(Config.defaultPath).
    """

func log(_ message: String) {
    let time = ISO8601DateFormatter.string(
        from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime]
    )
    FileHandle.standardError.write(Data("\(time) \(message)\n".utf8))
}

/// Where to grant the Accessibility permission. macOS 27 renamed the list in
/// System Settings.
let permissionHint = "turn on Move in System Settings, Device Control and Data Access (Accessibility before macOS 27)"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("move: \(message)\n".utf8))
    exit(1)
}

var command = "run"
var configPath = Config.defaultPath
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "run", "check":
        command = argument
    case "--config":
        guard let path = arguments.popFirst() else { fail("--config needs a path") }
        configPath = path
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        fail("unknown argument '\(argument)'\n\n\(usage)")
    }
}

if command == "check" {
    do {
        let config = try Config.load(path: configPath)
        print("\(configPath): ok, \(config.bindings.count) bindings")
        exit(0)
    } catch {
        fail("\(error)")
    }
}

/// Loads the config, registers its shortcuts and reloads when the file
/// changes. A config that fails to load leaves the current shortcuts active.
@MainActor
final class Controller {
    private let path: String
    private lazy var hotKeys = HotKeys { frame in Windows.moveFocused(to: frame) }
    private lazy var watcher = FileWatcher(path: path) { [weak self] in self?.reload() }

    init(path: String) {
        self.path = path
    }

    func start() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            log("no permission to move windows yet, \(permissionHint)")
        }
        reload()
        watcher.start()
    }

    private func reload() {
        do {
            let config = try Config.load(path: path)
            hotKeys.set(config.bindings)
            log("loaded \(path), \(config.bindings.count) bindings")
        } catch {
            log("\(error), keeping the current shortcuts")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller(path: configPath)
controller.start()
app.run()
