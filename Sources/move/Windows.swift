import AppKit
import ApplicationServices
import MoveCore

/// Moves the focused window of the frontmost app with the Accessibility API.
@MainActor
enum Windows {
    static func moveFocused(to frame: Frame) {
        guard AXIsProcessTrusted() else {
            log("no permission to move windows, \(permissionHint)")
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication else {
            log("no frontmost app")
            return
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = element(axApp, kAXFocusedWindowAttribute) else {
            log("\(app.localizedName ?? "app"): no focused window")
            return
        }
        guard let position = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute) else {
            log("\(app.localizedName ?? "app"): can't read the window frame")
            return
        }

        let screens = NSScreen.screens
        guard let mainScreen = screens.first else { return }
        let height = mainScreen.frame.height

        // Pick the screen in AppKit coordinates, then work in Accessibility
        // coordinates.
        let windowRect = flip(CGRect(origin: position, size: size), mainScreenHeight: height)
        let center = CGPoint(x: windowRect.midX, y: windowRect.midY)
        guard let index = screenIndex(containing: center, in: screens.map(\.frame)) else { return }
        let area = flip(screens[index].visibleFrame, mainScreenHeight: height)
        let rect = target(frame, in: area)

        // Chrome and Electron apps animate or ignore frame changes while
        // AXEnhancedUserInterface is on.
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        let enhanced = bool(axApp, enhancedKey) == true
        if enhanced {
            AXUIElementSetAttributeValue(axApp, enhancedKey, kCFBooleanFalse)
        }
        defer {
            if enhanced {
                AXUIElementSetAttributeValue(axApp, enhancedKey, kCFBooleanTrue)
            }
        }

        // Size, then position, then size again. Some apps clamp the size to
        // the screen the window is on before the move.
        set(window, kAXSizeAttribute, size: rect.size)
        set(window, kAXPositionAttribute, point: rect.origin)
        let status = set(window, kAXSizeAttribute, size: rect.size)
        if status != .success {
            log("\(app.localizedName ?? "app"): could not resize the window (AX error \(status.rawValue))")
        }
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = copy(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(element, attribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(element, attribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private static func bool(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    @discardableResult
    private static func set(_ element: AXUIElement, _ attribute: String, size: CGSize) -> AXError {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    @discardableResult
    private static func set(_ element: AXUIElement, _ attribute: String, point: CGPoint) -> AXError {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }
}
