import CoreGraphics
import Testing
@testable import MoveCore

@Suite struct GeometryTests {
    let left = Frame(x: 0, y: 0, w: 0.5, h: 1)
    let right = Frame(x: 0.5, y: 0, w: 0.5, h: 1)

    @Test func halvesMeetOnAnOddWidth() {
        let area = CGRect(x: 0, y: 25, width: 1513, height: 950)
        let a = target(left, in: area)
        let b = target(right, in: area)
        #expect(a.maxX == b.minX)
        #expect(a.minX == 0)
        #expect(b.maxX == 1513)
        #expect(a.width + b.width == 1513)
        #expect(a.minY == 25 && a.height == 950)
    }

    @Test func centeredThreeQuarters() {
        let area = CGRect(x: 0, y: 25, width: 1600, height: 1000)
        let rect = target(Frame(x: 0.125, y: 0, w: 0.75, h: 1), in: area)
        #expect(rect == CGRect(x: 200, y: 25, width: 1200, height: 1000))
    }

    @Test func offsetArea() {
        // A second screen to the left of the main screen.
        let area = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let rect = target(right, in: area)
        #expect(rect == CGRect(x: -960, y: -200, width: 960, height: 1080))
    }

    @Test func flipIsItsOwnInverse() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 400)
        #expect(flip(flip(rect, mainScreenHeight: 1117), mainScreenHeight: 1117) == rect)
    }

    @Test func flipVisibleFrameOfMainScreen() {
        // Main screen 1728x1117 with a 33 pt menu bar and no Dock at the
        // bottom. AppKit's visible frame starts at y 0 and is 1084 tall.
        let visible = CGRect(x: 0, y: 0, width: 1728, height: 1084)
        #expect(flip(visible, mainScreenHeight: 1117) == CGRect(x: 0, y: 33, width: 1728, height: 1084))
    }

    @Test func flipScreenAboveMain() {
        // A 2560x1440 screen above the main screen, in AppKit coordinates.
        let above = CGRect(x: -400, y: 1117, width: 2560, height: 1440)
        #expect(flip(above, mainScreenHeight: 1117) == CGRect(x: -400, y: -1440, width: 2560, height: 1440))
    }

    @Test func screenContainingPoint() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1728, height: 1117),
            CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        ]
        #expect(screenIndex(containing: CGPoint(x: 100, y: 100), in: screens) == 0)
        #expect(screenIndex(containing: CGPoint(x: -100, y: 100), in: screens) == 1)
    }

    @Test func pointOffScreenPicksTheClosest() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1728, height: 1117),
            CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        ]
        #expect(screenIndex(containing: CGPoint(x: -500, y: 1100), in: screens) == 1)
        #expect(screenIndex(containing: CGPoint(x: 2000, y: 2000), in: screens) == 0)
        #expect(screenIndex(containing: .zero, in: []) == nil)
    }
}
