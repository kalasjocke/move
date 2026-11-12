import Carbon.HIToolbox

/// Modifier keys, stored as the Carbon modifier mask that
/// `RegisterEventHotKey` takes.
public struct Modifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let cmd = Modifiers(rawValue: UInt32(cmdKey))
    public static let shift = Modifiers(rawValue: UInt32(shiftKey))
    public static let alt = Modifiers(rawValue: UInt32(optionKey))
    public static let ctrl = Modifiers(rawValue: UInt32(controlKey))
}

/// A hotkey: one key plus modifiers. The key is a Carbon virtual key code,
/// which names a physical key position, not a character.
public struct Shortcut: Hashable, Sendable {
    public let key: UInt32
    public let modifiers: Modifiers

    public init(key: UInt32, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Parses text such as `cmd+shift+1`. Modifiers come first in any order,
    /// then exactly one key. The error is a message without location.
    public static func parse(_ text: String) throws(ConfigError) -> Shortcut {
        let parts = text.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let keyName = parts.last, parts.count >= 2 else {
            throw ConfigError("'\(text)' needs at least one modifier and a key, for example cmd+shift+1")
        }

        var modifiers: Modifiers = []
        for name in parts.dropLast() {
            guard let modifier = modifierNames[name] else {
                if keyCodes[name] != nil {
                    throw ConfigError("'\(text)' has more than one key, put the key last")
                }
                throw ConfigError("'\(text)' has unknown modifier '\(name)', use cmd, shift, alt, opt or ctrl")
            }
            guard !modifiers.contains(modifier) else {
                throw ConfigError("'\(text)' repeats modifier '\(name)'")
            }
            modifiers.insert(modifier)
        }

        guard let key = keyCodes[keyName] else {
            if modifierNames[keyName] != nil {
                throw ConfigError("'\(text)' has no key, put the key last")
            }
            throw ConfigError("'\(text)' has unknown key '\(keyName)'")
        }
        return Shortcut(key: UInt32(key), modifiers: modifiers)
    }
}

private let modifierNames: [String: Modifiers] = [
    "cmd": .cmd, "shift": .shift, "alt": .alt, "opt": .alt, "ctrl": .ctrl,
]

private let keyCodes: [String: Int] = {
    var codes: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "return": kVK_Return, "enter": kVK_Return,
        "space": kVK_Space, "tab": kVK_Tab, "escape": kVK_Escape,
        "left": kVK_LeftArrow, "right": kVK_RightArrow,
        "up": kVK_UpArrow, "down": kVK_DownArrow,
    ]
    let functionKeys = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
        kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
    ]
    for (index, code) in functionKeys.enumerated() {
        codes["f\(index + 1)"] = code
    }
    return codes
}()
