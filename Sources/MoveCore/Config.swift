import Foundation
import Yams

public struct ConfigError: Error, CustomStringConvertible, Equatable {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// A window frame as fractions of the screen's usable area, measured from
/// the top left.
public struct Frame: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

public struct Binding: Equatable, Sendable {
    /// The shortcut as written in the config, for log messages.
    public let text: String
    public let shortcut: Shortcut
    public let frame: Frame
}

public struct Config: Equatable, Sendable {
    public let bindings: [Binding]

    public static var defaultPath: String {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config").path
        return (base as NSString).appendingPathComponent("move/config.yaml")
    }

    public static func load(path: String) throws -> Config {
        let yaml: String
        do {
            yaml = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw ConfigError("\(path): can't read the file")
        }
        do {
            return try parse(yaml)
        } catch {
            throw ConfigError("\(path): \(error.description)")
        }
    }

    public static func parse(_ yaml: String) throws(ConfigError) -> Config {
        let root: Node?
        do {
            root = try Yams.compose(yaml: yaml)
        } catch let YamlError.duplicatedKeysInMapping(duplicates, context) {
            let keys = duplicates.map { "'\($0)'" }.joined(separator: ", ")
            throw ConfigError("line \(context.mark.line): duplicate key \(keys)")
        } catch let error as YamlError {
            throw ConfigError("invalid YAML: \(yamlProblem(error))")
        } catch {
            throw ConfigError("invalid YAML: \(error)")
        }

        guard let mapping = root?.mapping else {
            throw ConfigError("the config must be a mapping with a 'bindings' key")
        }
        var bindingsNode: Node?
        for (key, value) in mapping {
            guard key.string == "bindings" else {
                throw ConfigError("line \(line(key)): unknown key '\(key.string ?? "?")', the only key is 'bindings'")
            }
            bindingsNode = value
        }
        guard let bindingsNode else {
            throw ConfigError("the config has no 'bindings' key")
        }
        guard let pairs = bindingsNode.mapping else {
            throw ConfigError("line \(line(bindingsNode)): 'bindings' must map shortcuts to frames")
        }

        var bindings: [Binding] = []
        var seen: [Shortcut: String] = [:]
        for (key, value) in pairs {
            guard let text = key.scalar?.string else {
                throw ConfigError("line \(line(key)): a shortcut must be text such as cmd+shift+1")
            }
            let prefix = "line \(line(key)), \(text)"
            let shortcut: Shortcut
            do {
                shortcut = try Shortcut.parse(text)
            } catch {
                throw ConfigError("\(prefix): \(error.description)")
            }
            if let other = seen[shortcut] {
                throw ConfigError("\(prefix): same shortcut as '\(other)'")
            }
            seen[shortcut] = text
            let frame: Frame
            do {
                frame = try parseFrame(value)
            } catch {
                throw ConfigError("\(prefix): \(error.description)")
            }
            bindings.append(Binding(text: text, shortcut: shortcut, frame: frame))
        }
        return Config(bindings: bindings)
    }
}

private let tolerance = 1e-9

private func parseFrame(_ node: Node) throws(ConfigError) -> Frame {
    guard let mapping = node.mapping else {
        throw ConfigError("the frame must be a mapping such as { w: 1/2, h: 1 }")
    }
    var values: [String: Double] = [:]
    var center = false
    for (key, value) in mapping {
        let name = key.string ?? "?"
        switch name {
        case "x", "y", "w", "h":
            values[name] = try fraction(value, field: name)
        case "center":
            guard let flag = value.bool else {
                throw ConfigError("'center' must be true or false")
            }
            center = flag
        default:
            throw ConfigError("unknown field '\(name)', use x, y, w, h or center")
        }
    }

    guard let w = values["w"] else { throw ConfigError("'w' is required") }
    guard let h = values["h"] else { throw ConfigError("'h' is required") }
    guard w > 0 else { throw ConfigError("'w' must be greater than 0") }
    guard h > 0 else { throw ConfigError("'h' must be greater than 0") }

    if center {
        guard values["x"] == nil, values["y"] == nil else {
            throw ConfigError("'center' can't be combined with 'x' or 'y'")
        }
        return Frame(x: (1 - w) / 2, y: (1 - h) / 2, w: w, h: h)
    }

    let x = values["x"] ?? 0
    let y = values["y"] ?? 0
    guard x + w <= 1 + tolerance else { throw ConfigError("x + w is greater than 1") }
    guard y + h <= 1 + tolerance else { throw ConfigError("y + h is greater than 1") }
    return Frame(x: x, y: y, w: w, h: h)
}

/// Reads `1/2`, `0.5` or `1` and checks that it is between 0 and 1.
private func fraction(_ node: Node, field: String) throws(ConfigError) -> Double {
    let invalid = ConfigError("'\(field)' must be a fraction between 0 and 1, such as 1/2, 0.5 or 1")
    guard let text = node.scalar?.string.trimmingCharacters(in: .whitespaces) else { throw invalid }

    let value: Double
    let parts = text.split(separator: "/", omittingEmptySubsequences: false)
    switch parts.count {
    case 1:
        guard let number = Double(text) else { throw invalid }
        value = number
    case 2:
        let top = parts[0].trimmingCharacters(in: .whitespaces)
        let bottom = parts[1].trimmingCharacters(in: .whitespaces)
        guard let numerator = Double(top), let denominator = Double(bottom), denominator != 0 else {
            throw invalid
        }
        value = numerator / denominator
    default:
        throw invalid
    }
    guard value.isFinite, value >= 0, value <= 1 else { throw invalid }
    return value
}

private func line(_ node: Node) -> Int {
    node.mark?.line ?? 0
}

/// Yams error descriptions can repeat the whole file. Keep only the first
/// line, which holds the problem and its position.
private func yamlProblem(_ error: YamlError) -> String {
    String(describing: error)
        .split(separator: "\n", omittingEmptySubsequences: true)
        .first
        .map(String.init) ?? "parse error"
}
