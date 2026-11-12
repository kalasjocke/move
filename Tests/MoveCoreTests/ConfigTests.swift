import Carbon.HIToolbox
import Testing
@testable import MoveCore

@Suite struct ShortcutTests {
    @Test func parsesModifiersAndKey() throws {
        let shortcut = try Shortcut.parse("cmd+shift+1")
        #expect(shortcut == Shortcut(key: UInt32(kVK_ANSI_1), modifiers: [.cmd, .shift]))
    }

    @Test func modifierOrderDoesNotMatter() throws {
        #expect(try Shortcut.parse("shift+cmd+1") == Shortcut.parse("cmd+shift+1"))
    }

    @Test func enterIsReturnAndOptIsAlt() throws {
        #expect(try Shortcut.parse("cmd+enter") == Shortcut.parse("cmd+return"))
        #expect(try Shortcut.parse("opt+left") == Shortcut.parse("alt+left"))
    }

    @Test func functionKeys() throws {
        #expect(try Shortcut.parse("ctrl+f12").key == UInt32(kVK_F12))
    }

    @Test(arguments: [
        ("1", "needs at least one modifier"),
        ("cmd+", "unknown key ''"),
        ("cmd+shift", "has no key"),
        ("cmd+1+2", "more than one key"),
        ("super+1", "unknown modifier 'super'"),
        ("cmd+cmd+1", "repeats modifier 'cmd'"),
        ("cmd+Return", "unknown key 'Return'"),
        ("cmd+-", "unknown key '-'"),
    ])
    func rejects(text: String, message: String) {
        #expect {
            try Shortcut.parse(text)
        } throws: { error in
            (error as? ConfigError)?.description.contains(message) == true
        }
    }
}

@Suite struct ConfigTests {
    let example = """
        bindings:
          cmd+shift+1:      { w: 1/2, h: 1 }
          cmd+shift+2:      { x: 1/2, w: 1/2, h: 1 }
          cmd+return:       { w: 1, h: 1 }
          cmd+shift+return: { w: 3/4, h: 1, center: true }
        """

    @Test func parsesTheExample() throws {
        let config = try Config.parse(example)
        #expect(config.bindings.map(\.text) == ["cmd+shift+1", "cmd+shift+2", "cmd+return", "cmd+shift+return"])
        #expect(config.bindings.map(\.frame) == [
            Frame(x: 0, y: 0, w: 0.5, h: 1),
            Frame(x: 0.5, y: 0, w: 0.5, h: 1),
            Frame(x: 0, y: 0, w: 1, h: 1),
            Frame(x: 0.125, y: 0, w: 0.75, h: 1),
        ])
    }

    @Test func fractionFormats() throws {
        let config = try Config.parse("""
            bindings:
              cmd+1: { x: 0.25, y: 0, w: 1/2, h: 1 }
              cmd+2: { w: 2 / 3, h: .5 }
            """)
        #expect(config.bindings[0].frame == Frame(x: 0.25, y: 0, w: 0.5, h: 1))
        #expect(config.bindings[1].frame == Frame(x: 0, y: 0, w: 2.0 / 3.0, h: 0.5))
    }

    @Test func centerCentersBothWays() throws {
        let config = try Config.parse("bindings:\n  cmd+1: { w: 1/2, h: 1/2, center: true }")
        #expect(config.bindings[0].frame == Frame(x: 0.25, y: 0.25, w: 0.5, h: 0.5))
    }

    @Test func emptyBindings() throws {
        #expect(try Config.parse("bindings: {}").bindings.isEmpty)
    }

    @Test(arguments: [
        ("", "must be a mapping"),
        ("- a", "must be a mapping"),
        ("other: 1", "line 1: unknown key 'other'"),
        ("bindings: [a]", "line 1: 'bindings' must map"),
        ("bindings:\n  cmd+1: { w: 1 }", "line 2, cmd+1: 'h' is required"),
        ("bindings:\n  cmd+1: { h: 1 }", "line 2, cmd+1: 'w' is required"),
        ("bindings:\n  cmd+1: { w: 0, h: 1 }", "'w' must be greater than 0"),
        ("bindings:\n  cmd+1: { w: 3/2, h: 1 }", "'w' must be a fraction"),
        ("bindings:\n  cmd+1: { w: -1, h: 1 }", "'w' must be a fraction"),
        ("bindings:\n  cmd+1: { w: 1/0, h: 1 }", "'w' must be a fraction"),
        ("bindings:\n  cmd+1: { w: half, h: 1 }", "'w' must be a fraction"),
        ("bindings:\n  cmd+1: { x: 1/2, w: 3/4, h: 1 }", "x + w is greater than 1"),
        ("bindings:\n  cmd+1: { y: 1/2, w: 1, h: 3/4 }", "y + h is greater than 1"),
        ("bindings:\n  cmd+1: { x: 0, w: 1/2, h: 1, center: true }", "can't be combined"),
        ("bindings:\n  cmd+1: { w: 1, h: 1, center: yes please }", "'center' must be true or false"),
        ("bindings:\n  cmd+1: { w: 1, h: 1, z: 0 }", "unknown field 'z'"),
        ("bindings:\n  cmd+1: full", "the frame must be a mapping"),
        ("bindings:\n  1: { w: 1, h: 1 }", "line 2, 1: '1' needs at least one modifier"),
        ("bindings:\n  cmd+shift+1: { w: 1, h: 1 }\n  shift+cmd+1: { w: 1, h: 1 }", "line 3, shift+cmd+1: same shortcut as 'cmd+shift+1'"),
        ("bindings:\n  cmd+1: { w: 1, h: 1 }\n  cmd+1: { w: 1, h: 1 }", "line 2: duplicate key 'cmd+1'"),
        ("bindings: {", "invalid YAML"),
    ])
    func rejects(yaml: String, message: String) {
        #expect {
            try Config.parse(yaml)
        } throws: { error in
            let description = (error as? ConfigError)?.description ?? ""
            if !description.contains(message) {
                Issue.record("got: \(description)")
                return false
            }
            return true
        }
    }
}
